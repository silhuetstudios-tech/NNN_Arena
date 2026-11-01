(function(root){
'use strict';
const START=Date.parse('2026-11-01T00:00:00+05:30');
const END=Date.parse('2026-12-01T00:00:00+05:30');
const DAY=86400000;
const NAMES=['Aryan','Andrew','Adnan','Aman'];
function dayAt(time=Date.now()){return time<START?0:time>=END?31:Math.floor((time-START)/DAY)+1;}
function fresh(){return {version:1,players:NAMES.map((name,i)=>({name,avatar:i,claimed:false,checks:[],failedAt:null,failedDay:null})),events:[]};}
function stats(p,day){
 const checks=[...new Set(p.checks)].filter(n=>n>=1&&n<=30&&n<=day).sort((a,b)=>a-b);
 let longest=0,run=0,last=0;
 for(const d of checks){run=d===last+1?run+1:1;longest=Math.max(longest,run);last=d;}
 let streak=0,cursor=Math.min(day,30);
 if(!checks.includes(cursor))cursor--;
 while(cursor>0&&checks.includes(cursor)){streak++;cursor--;}
 if(p.failedAt)streak=0;
 const xp=checks.length*100+[3,7,14,21,30].filter(n=>longest>=n).length*250;
 return {checks,streak,longest,xp,level:Math.floor(xp/500)+1};
}
function order(players,day){return [...players].sort((a,b)=>Number(!!a.failedAt)-Number(!!b.failedAt)||stats(b,day).xp-stats(a,day).xp||a.name.localeCompare(b.name));}
function rank(players,p,day){return 1+players.filter(q=>Number(!!q.failedAt)<Number(!!p.failedAt)||(!!q.failedAt===!!p.failedAt&&stats(q,day).xp>stats(p,day).xp)).length;}
function checkAllowed(p,d,now){const today=dayAt(now);return !p.failedAt&&today>=1&&today<=30&&Number.isInteger(d)&&d>=Math.max(1,today-1)&&d<=today&&!p.checks.includes(d);}
function apply(state,name,action,d,now=Date.now()){
 const p=state.players.find(x=>x.name===name);if(!p)throw Error('Choose a contestant first.');
 if(action==='check'){
  if(!checkAllowed(p,d,now))throw Error('Only today or yesterday can be checked in. Future days are locked.');
  p.checks.push(d);p.checks.sort((a,b)=>a-b);
  state.events.unshift({name,action:'check',day:d,at:now});
 }else if(action==='fail'){
  if(p.failedAt||dayAt(now)<1||dayAt(now)>30)throw Error('This action is unavailable.');
  p.failedAt=now;p.failedDay=dayAt(now);state.events.unshift({name,action:'fail',day:dayAt(now),at:now});
 }else if(action==='undo'){
  if(!p.failedAt||now-p.failedAt>300000)throw Error('The five-minute undo window has closed.');
  p.failedAt=null;p.failedDay=null;state.events=state.events.filter(e=>!(e.name===name&&e.action==='fail'));
 }else throw Error('Unknown action.');
 state.events=state.events.slice(0,60);return state;
}
const api={START,END,DAY,NAMES,dayAt,fresh,stats,order,rank,checkAllowed,apply};
if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.NNN=api;
})(typeof window!=='undefined'?window:globalThis);
