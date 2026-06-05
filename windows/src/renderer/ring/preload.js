'use strict';
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('ring', {
  onState(callback) {
    ipcRenderer.on('ring:state', (_event, state) => callback(state));
  },
});
