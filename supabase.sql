-- Run this ONCE in a new Supabase project's SQL Editor.
-- Only nnn_api is exposed. Tables, PIN hashes and sessions stay private.
begin;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
create schema if not exists nnn_private;
revoke all on schema nnn_private from public, anon, authenticated;
create table if not exists nnn_private.rooms (
 id text primary key, created_at timestamptz not null default now()
);
create table if not exists nnn_private.players (
 room text references nnn_private.rooms(id) on delete cascade,
 name text not null check(name in ('Aryan','Andrew','Adnan','Aman')),
 avatar integer not null,
 pin_hash text,
 checks integer[] not null default '{}',
 failed_at timestamptz,
 failed_day integer,
 attempts integer not null default 0,
 locked_until timestamptz,
 primary key(room,name)
);
create table if not exists nnn_private.sessions (
 token_hash text primary key, room text not null, name text not null,
 expires_at timestamptz not null default (now()+interval '31 days'),
 foreign key(room,name) references nnn_private.players(room,name) on delete cascade
);
create table if not exists nnn_private.events (
 id bigint generated always as identity primary key,
 room text not null references nnn_private.rooms(id) on delete cascade,
 name text not null, action text not null, day integer not null,
 at timestamptz not null default now()
);
alter table nnn_private.rooms enable row level security;
alter table nnn_private.players enable row level security;
alter table nnn_private.sessions enable row level security;
alter table nnn_private.events enable row level security;
revoke all on all tables in schema nnn_private from public,anon,authenticated;

create or replace function nnn_private.snapshot(p_room text) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('version',1,
 'players',(select jsonb_agg(jsonb_build_object(
   'name',p.name,'avatar',p.avatar,'claimed',p.pin_hash is not null,
   'checks',to_jsonb(p.checks),
   'failedAt',case when p.failed_at is null then null else floor(extract(epoch from p.failed_at)*1000)::bigint end,
   'failedDay',p.failed_day) order by p.avatar)
   from nnn_private.players p where p.room=p_room),
 'events',coalesce((select jsonb_agg(jsonb_build_object(
   'name',e.name,'action',e.action,'day',e.day,
   'at',floor(extract(epoch from e.at)*1000)::bigint) order by e.id desc)
   from (select * from nnn_private.events where room=p_room order by id desc limit 60) e),'[]'::jsonb));
$$;
revoke all on function nnn_private.snapshot(text) from public,anon,authenticated;

create or replace function public.nnn_api(
 p_action text,p_room text,p_name text default '',p_token text default '',p_data jsonb default '{}'::jsonb
) returns jsonb language plpgsql security definer set search_path='' as $$
declare
 p nnn_private.players%rowtype;
 v_token text; v_day integer; v_today integer;
 v_now timestamptz := now();
 v_reply jsonb;
begin
 if p_room is null or p_room !~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
   return jsonb_build_object('error','Invalid squad invite.');
 end if;
 -- Serializes claim/check-in races across the four phones.
 perform pg_advisory_xact_lock(hashtextextended(p_room,0));
 if p_action='create' then
   if exists(select 1 from nnn_private.rooms where id=p_room) then
     return jsonb_build_object('error','This squad already exists. Join it instead.');
   end if;
   insert into nnn_private.rooms(id) values(p_room);
   insert into nnn_private.players(room,name,avatar) values
    (p_room,'Aryan',0),(p_room,'Andrew',1),(p_room,'Adnan',2),(p_room,'Aman',3);
 elsif not exists(select 1 from nnn_private.rooms where id=p_room) then
   return jsonb_build_object('error','Squad not found. Check your invite link.');
 end if;
 v_today := ((v_now at time zone 'Asia/Kolkata')::date-date '2026-11-01')+1;
 if p_action='login' then
   select * into p from nnn_private.players where room=p_room and name=p_name for update;
   if not found then return jsonb_build_object('error','Unknown contestant.'); end if;
   if p.locked_until is not null and p.locked_until>v_now then
     return jsonb_build_object('error','Too many attempts. Try again in ten minutes.');
   end if;
   if coalesce(p_data->>'pin','') !~ '^[0-9]{6,12}$' then
     return jsonb_build_object('error','Use a PIN with 6–12 digits.');
   end if;
   if p.pin_hash is null then
     update nnn_private.players set pin_hash=extensions.crypt(p_data->>'pin',extensions.gen_salt('bf',10)) where room=p_room and name=p_name;
   elsif extensions.crypt(p_data->>'pin',p.pin_hash)<>p.pin_hash then
     update nnn_private.players set
       attempts=case when locked_until is not null and locked_until<=v_now then 1 else attempts+1 end,
       locked_until=case when (case when locked_until is not null and locked_until<=v_now then 1 else attempts+1 end)>=5 then v_now+interval '10 minutes' else null end
       where room=p_room and name=p_name;
     return jsonb_build_object('error','Incorrect PIN. Five incorrect tries lock this profile for ten minutes.');
   end if;
   update nnn_private.players set attempts=0,locked_until=null where room=p_room and name=p_name;
   delete from nnn_private.sessions where room=p_room and name=p_name and expires_at<v_now;
   v_token:=encode(extensions.gen_random_bytes(32),'hex');
   insert into nnn_private.sessions(token_hash,room,name) values(encode(extensions.digest(v_token,'sha256'),'hex'),p_room,p_name);
 elsif p_action='mutate' then
   if not exists(select 1 from nnn_private.sessions where room=p_room and name=p_name
      and token_hash=encode(extensions.digest(coalesce(p_token,''),'sha256'),'hex') and expires_at>v_now) then
     return jsonb_build_object('error','Your profile is locked. Switch to another player, then unlock yours again.');
   end if;
   select * into p from nnn_private.players where room=p_room and name=p_name for update;
   if p_data->>'action'='check' then
     if coalesce(p_data->>'day','') !~ '^([1-9]|[12][0-9]|30)$' then
       return jsonb_build_object('error','Invalid day.');
     end if;
     v_day:=(p_data->>'day')::integer;
     if v_today<1 or v_today>30 or p.failed_at is not null or v_day>v_today or v_day<greatest(1,v_today-1) or v_day=any(p.checks) then
       return jsonb_build_object('error','Only today or yesterday can be checked in, once per day. Future days are locked.');
     end if;
     update nnn_private.players set checks=array(select x from unnest(p.checks||v_day) x order by x) where room=p_room and name=p_name;
     insert into nnn_private.events(room,name,action,day) values(p_room,p_name,'check',v_day);
   elsif p_data->>'action'='fail' then
     if v_today<1 or v_today>30 or p.failed_at is not null then
       return jsonb_build_object('error','This action is unavailable.');
     end if;
     update nnn_private.players set failed_at=v_now,failed_day=v_today where room=p_room and name=p_name;
     insert into nnn_private.events(room,name,action,day) values(p_room,p_name,'fail',v_today);
   elsif p_data->>'action'='undo' then
     if p.failed_at is null or v_now-p.failed_at>interval '5 minutes' then
       return jsonb_build_object('error','The five-minute undo window has closed.');
     end if;
     update nnn_private.players set failed_at=null,failed_day=null where room=p_room and name=p_name;
     delete from nnn_private.events where room=p_room and name=p_name and action='fail';
   else return jsonb_build_object('error','Unknown action.');
   end if;
 elsif p_action not in ('read','create') then
   return jsonb_build_object('error','Unknown action.');
 end if;
 v_reply:=jsonb_build_object('state',nnn_private.snapshot(p_room),'serverTime',floor(extract(epoch from v_now)*1000)::bigint);
 if v_token is not null then v_reply:=v_reply||jsonb_build_object('token',v_token);end if;
 return v_reply;
end;
$$;
revoke all on function public.nnn_api(text,text,text,text,jsonb) from public,anon,authenticated;
grant execute on function public.nnn_api(text,text,text,text,jsonb) to anon;
commit;
