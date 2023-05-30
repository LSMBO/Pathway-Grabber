const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('electronAPI', {
  browseFile: () => ipcRenderer.invoke('dialog:browseFile'),
  clickSubmit: (args) => ipcRenderer.invoke('click-submit', args),
  getDimensions: (args) => ipcRenderer.invoke('get-dimensions', args),
  exportOutput: () => ipcRenderer.send('export-output'),
  getTestInputFile: () => ipcRenderer.invoke('test'),
})

window.addEventListener('DOMContentLoaded', () => {
})