const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('notepad',Object.freeze({
  load:()=>ipcRenderer.invoke('load'),
  open:()=>ipcRenderer.invoke('open'),
  save:(tab,as)=>ipcRenderer.invoke('save',tab,as),
  snapshot:session=>ipcRenderer.invoke('snapshot',session),
  confirmClose:title=>ipcRenderer.invoke('confirm-close',title),
  update:manual=>ipcRenderer.invoke('update',manual),
  cancelUpdate:()=>ipcRenderer.invoke('cancel-update'),
  installUpdate:()=>ipcRenderer.invoke('install-update'),
  onUpdate:fn=>ipcRenderer.on('update-state',(_event,state)=>fn(state)),
  external:kind=>ipcRenderer.invoke('external',kind),
  copyDonation:()=>ipcRenderer.invoke('copy-donation'),
  onCommand:fn=>ipcRenderer.on('command',(_event,command)=>fn(command))
}));
