import {Capacitor} from '@capacitor/core';
import {Filesystem,Directory,Encoding} from '@capacitor/filesystem';
import {journal} from './journal.mjs';
import {restore} from './model.mjs';
const native=Capacitor.isNativePlatform();
const adapter=native?{
 async read(slot){try{return (await Filesystem.readFile({path:`session-${slot}.json`,directory:Directory.Data,encoding:Encoding.UTF8})).data;}catch(e){if(String(e.code)==='OS-PLUG-FILE-0008'||/not exist|not found|no such file/i.test(String(e.message)))return null;throw e;}},
 async write(slot,data){await Filesystem.writeFile({path:`session-${slot}.json`,directory:Directory.Data,data,encoding:Encoding.UTF8});}

}:{async read(slot){return localStorage.getItem('notepad-mobile-'+slot);},async write(slot,data){localStorage.setItem('notepad-mobile-'+slot,data);}};
export const storage=journal(adapter,restore);
