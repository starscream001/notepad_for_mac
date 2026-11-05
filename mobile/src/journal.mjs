// Two alternating slots. A failed write keeps the last valid generation intact.
export function journal(adapter,validate){
 let serial=Promise.resolve(),generation=0;
 async function read(){
  const slots=await Promise.all(['a','b'].map(async slot=>{
   const raw=await adapter.read(slot);if(raw==null)return null;
   try{const record=JSON.parse(raw);if(record.format!==1||!Number.isSafeInteger(record.generation)||record.generation<1)throw Error();return {generation:record.generation,value:validate(record.value)};}catch{return {damaged:true};}
  }));
  const valid=slots.filter(s=>s&&!s.damaged).sort((a,b)=>b.generation-a.generation);
  if(!valid.length){if(slots.some(Boolean))throw Error('storage_damaged');return null;}
  generation=valid[0].generation;return valid[0].value;
 }
 function save(value){const snapshot=validate(structuredClone(value));const task=serial.catch(()=>{}).then(async()=>{const next=generation+1;await adapter.write(next%2?'a':'b',JSON.stringify({format:1,generation:next,value:snapshot}));generation=next;});serial=task;return task;}
 return {read,save,flush:()=>serial};
}
