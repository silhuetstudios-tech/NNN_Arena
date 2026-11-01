(function(root){
  'use strict';
  const PREFIX='nnn-session-v2:';
  const LIFETIME=31*86400000;
  function create(storage,names,clock=Date.now){
    function key(scope){return PREFIX+scope;}
    function clear(scope){storage.removeItem(key(scope));}
    function read(scope){
      try{
        const saved=JSON.parse(storage.getItem(key(scope))||'null');
        if(!saved)return null;
        if(!names.includes(saved.name)||!Number.isFinite(saved.expiresAt)||saved.expiresAt<=clock()||
          (scope!=='local'&&(typeof saved.token!=='string'||!saved.token))){clear(scope);return null;}
        return saved;
      }catch{return null;}
    }
    function write(scope,name,token=null){
      if(!names.includes(name))throw Error('Choose a valid contestant.');
      if(scope!=='local'&&(!token||typeof token!=='string'))throw Error('Unlock your profile again.');
      const saved={name,token,expiresAt:clock()+LIFETIME};
      storage.setItem(key(scope),JSON.stringify(saved));
      return saved;
    }
    return {read,write,clear,key};
  }
  const api={create,LIFETIME};
  if(typeof module!=='undefined'&&module.exports)module.exports=api;else root.NNNSessions=api;
})(typeof window!=='undefined'?window:globalThis);
