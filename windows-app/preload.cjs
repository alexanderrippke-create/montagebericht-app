const {contextBridge,ipcRenderer}=require('electron');
contextBridge.exposeInMainWorld('desktopReport',{openReport:()=>ipcRenderer.invoke('open-report'),saveReport:(data)=>ipcRenderer.invoke('save-report',data),checkUpdate:()=>ipcRenderer.invoke('check-update'),openUpdate:()=>ipcRenderer.invoke('open-update'),reloadReport:()=>ipcRenderer.invoke('reload-report'),finalize:()=>ipcRenderer.invoke('finalize-report'),savePdf:()=>ipcRenderer.invoke('save-pdf'),outlookDraft:(data)=>ipcRenderer.invoke('outlook-draft',data),readCalendar:(range)=>ipcRenderer.invoke('read-calendar',range)});

