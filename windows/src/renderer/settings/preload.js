'use strict';
const { contextBridge, ipcRenderer } = require('electron');
const {
  SLOT_COLORS, SPECIAL_KEYS, SYSTEM_ACTIONS, VALID_SLOT_COUNTS,
  mouseButtonLabel, describeAction, emptySlot, renderedSlots,
} = require('../../shared/models');
const { ICONS, iconGlyph } = require('../ring/icons');

contextBridge.exposeInMainWorld('api', {
  getSettings: () => ipcRenderer.invoke('settings:get'),
  updateSettings: (partial) => ipcRenderer.invoke('settings:update', partial),
  recordTrigger: () => ipcRenderer.invoke('settings:recordTrigger'),
  cancelRecord: () => ipcRenderer.invoke('settings:cancelRecord'),
  preview: (ms) => ipcRenderer.invoke('settings:preview', ms),
  listProfiles: () => ipcRenderer.invoke('profiles:list'),
  saveProfile: (p) => ipcRenderer.invoke('profiles:save', p),
  deleteProfile: (id) => ipcRenderer.invoke('profiles:delete', id),
  setProfileEnabled: (p, enabled) => ipcRenderer.invoke('profiles:setEnabled', p, enabled),
  editableCopy: (p) => ipcRenderer.invoke('profiles:editableCopy', p),
  newProfile: (name, appId) => ipcRenderer.invoke('profiles:new', { name, appId }),
  selectableApps: () => ipcRenderer.invoke('apps:selectable'),
  chooseFile: () => ipcRenderer.invoke('dialog:chooseFile'),
});

contextBridge.exposeInMainWorld('helpers', {
  SLOT_COLORS,
  SPECIAL_KEYS,
  SYSTEM_ACTIONS,
  VALID_SLOT_COUNTS,
  ICONS,
  iconGlyph: (name) => iconGlyph(name),
  mouseButtonLabel: (n) => mouseButtonLabel(n),
  describeAction: (a) => describeAction(a),
  emptySlot: (pos) => emptySlot(pos),
  renderedSlots: (p) => renderedSlots(p),
});
