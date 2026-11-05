// No native dependencies here: network, secure storage, clock and browser are injected.
const validToken=s=>typeof s==='string'&&/^[A-Za-z0-9_-]{10,1024}$/.test(s);
export function profile(value){if(!value||!Number.isSafeInteger(value.id)||value.id<1||typeof value.login!=='string'||!/^[A-Za-z0-9][A-Za-z0-9-]{0,38}$/.test(value.login))throw Error('invalid_response');return {id:value.id,login:value.login,name:typeof value.name==='string'?value.name.replace(/[\x00-\x1f]/g,' ').slice(0,100):null};}
export class GitHubAccount {
 constructor({clientID,storage,request,openBrowser,emit=()=>{},now=Date.now,sleep=ms=>new Promise(r=>setTimeout(r,ms))}){Object.assign(this,{clientID,storage,request,openBrowser,emit,now,sleep});this.epoch=0;this.saved=null;this.serial=Promise.resolve();this.state={phase:'signedOut'};}
 status(){return {...this.state,profile:this.saved?.profile||null};}
 update(value){this.state=value;this.emit(this.status());}
 queue(action){const result=this.serial.catch(()=>{}).then(action);this.serial=result;return result;}
 async load(){if(this.loaded)return;this.loaded=true;const epoch=this.epoch;this.update({phase:'loading'});try{const text=await this.storage.get();if(epoch!==this.epoch)return;if(text){const s=JSON.parse(text);if(s.provider!=='github-app'||s.clientID!==this.clientID||!validToken(s.token))throw Error('secure_storage');if(s.expiresAt&&s.expiresAt<=this.now()){await this.storage.remove();this.update({phase:'signedOut'});return;}s.profile=profile(s.profile);this.saved=s;}this.update({phase:this.saved?'connected':'signedOut'});}catch{if(epoch===this.epoch)this.update({phase:'error',error:'secure_storage'});}}

 cancel(){this.epoch++;this.update({phase:this.saved?'connected':'signedOut'});}
 async disconnect(){this.cancel();try{await this.queue(()=>this.storage.remove());this.saved=null;this.update({phase:'signedOut'});}catch{this.update({phase:'error',error:'secure_storage'});}}
 async start(){if(this.saved||['starting','waiting'].includes(this.state.phase))return;const epoch=++this.epoch;this.update({phase:'starting'});
  try{
   await this.storage.get();if(epoch!==this.epoch)return;
   const d=await this.request('https://github.com/login/device/code',{form:{client_id:this.clientID}});
   if(!d||typeof d.device_code!=='string'||!/^[A-Za-z0-9_-]{10,200}$/.test(d.device_code)||!/^[A-Z0-9]{4}-[A-Z0-9]{4}$/.test(d.user_code)||d.verification_uri!=='https://github.com/login/device'||!Number.isInteger(d.interval)||d.interval<1||d.interval>60||!Number.isInteger(d.expires_in)||d.expires_in<1||d.expires_in>1800)throw Error('invalid_response');
   if(epoch!==this.epoch)return;const expires=this.now()+d.expires_in*1000;let interval=d.interval;this.update({phase:'waiting',userCode:d.user_code});try{await this.openBrowser('https://github.com/login/device');}catch{if(epoch===this.epoch)this.update({...this.state,browserError:true});}
   while(epoch===this.epoch){if(this.now()+interval*1000>=expires)throw Error('expired');await this.sleep(interval*1000);if(epoch!==this.epoch)return;
    const r=await this.request('https://github.com/login/oauth/access_token',{form:{client_id:this.clientID,device_code:d.device_code,grant_type:'urn:ietf:params:oauth:grant-type:device_code'}});if(epoch!==this.epoch)return;if(this.now()>=expires)throw Error('expired');
    if(r.error==='authorization_pending')continue;if(r.error==='slow_down'){interval+=5;continue;}if(r.error)throw Error(r.error==='access_denied'?'denied':r.error==='expired_token'?'expired':'configuration');
    if(!validToken(r.access_token)||r.token_type?.toLowerCase()!=='bearer'||typeof r.scope!=='string'||r.scope.trim()||r.expires_in!==undefined&&(!Number.isInteger(r.expires_in)||r.expires_in<1||r.expires_in>31536000))throw Error('invalid_response');
    const p=profile(await this.request('https://api.github.com/user',{token:r.access_token}));if(epoch!==this.epoch)return;
    const saved={provider:'github-app',clientID:this.clientID,token:r.access_token,profile:p,expiresAt:r.expires_in?this.now()+r.expires_in*1000:null};
    await this.queue(async()=>{if(epoch!==this.epoch)return;await this.storage.set(JSON.stringify(saved));if(epoch===this.epoch){this.saved=saved;this.update({phase:'connected'});}else await this.storage.remove();});return;
   }
  }catch(e){if(epoch===this.epoch)this.update({phase:'error',error:['network','secure_storage','unauthorized','rate_limit','expired','denied','configuration','invalid_response'].includes(e.message)?e.message:'network'});}
 }
 async authorized(action){const saved=this.saved,epoch=this.epoch;if(!saved||saved.expiresAt&&saved.expiresAt<=this.now())throw Error('unauthorized');const result=await action(saved.token,saved.profile);if(epoch!==this.epoch)throw Error('cancelled');return result;}
}
