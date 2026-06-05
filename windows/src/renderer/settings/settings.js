'use strict';
/* global api, helpers */
// Settings renderer — parity with SettingsView/ProfilesView/ProfileEditorView/
// SlotEditorView/ActionEditorView/AppPickerView/SymbolPicker (mac).
// Windows deltas: modifier toggles are Ctrl/Shift/Alt (writing control/shift/
// option), shellScript runs PowerShell, appleScript/shortcutsApp are hidden
// (preserved via the Advanced kind), system actions use the Windows set.

const $ = (sel) => document.querySelector(sel);
const el = (tag, cls, text) => {
  const n = document.createElement(tag);
  if (cls) n.className = cls;
  if (text != null) n.textContent = text;
  return n;
};

let settings = null;
let hookInfo = null;

// curated symbols — same 53-name list as the mac SymbolPicker
const CURATED_SYMBOLS = [
  'doc.on.doc', 'doc.on.clipboard', 'scissors', 'arrow.uturn.backward', 'arrow.uturn.forward',
  'square.and.arrow.down', 'square.and.arrow.up', 'magnifyingglass', 'doc.text.magnifyingglass',
  'command', 'plus.square', 'xmark.square', 'xmark.circle', 'trash', 'pencil', 'folder',
  'play.fill', 'pause.fill', 'stop.fill', 'playpause.fill', 'forward.fill', 'backward.fill',
  'speaker.wave.2.fill', 'speaker.slash.fill', 'camera.viewfinder', 'bolt.fill', 'star.fill',
  'heart.fill', 'bookmark.fill', 'gearshape', 'terminal', 'hammer.fill', 'ladybug.fill',
  'link', 'globe', 'arrow.clockwise', 'chevron.left', 'chevron.right', 'sidebar.left',
  'rectangle.split.2x1', 'text.alignleft', 'bold', 'list.bullet', 'checkmark.circle',
  'bubble.left.fill', 'paperplane.fill', 'envelope.fill', 'calendar', 'bell.fill', 'lock.fill',
];

const SYSTEM_ACTION_LABELS = {
  lockScreen: 'Lock screen (Win+L)',
  screenshot: 'Screenshot — full screen (Win+PrtScn)',
  screenshotArea: 'Screenshot — area (Win+Shift+S)',
  volumeUp: 'Volume up', volumeDown: 'Volume down', mute: 'Mute',
  brightnessUp: 'Brightness up', brightnessDown: 'Brightness down',
  missionControl: 'Task View (Win+Tab)', showDesktop: 'Show desktop (Win+D)',
  launchpad: 'Start menu', notificationCenter: 'Notification center (Win+N)',
  mediaPlayPause: 'Media: play / pause', mediaNext: 'Media: next', mediaPrevious: 'Media: previous',
  sleep: 'Sleep',
};

// ---- bootstrap ------------------------------------------------------------------

async function init() {
  const info = await api.getSettings();
  settings = info.settings;
  hookInfo = info;
  bindTabs();
  bindGeneral();
  renderGeneral();
  await renderProfiles();

  // The hook can be (re)installed/dropped while Settings is open — keep the
  // status row honest by re-reading it periodically and on window focus.
  const refreshHookInfo = async () => {
    const info = await api.getSettings();
    hookInfo = info;
    if (!recording) renderGeneral();
  };
  setInterval(refreshHookInfo, 3000);
  window.addEventListener('focus', refreshHookInfo);
}

function bindTabs() {
  document.querySelectorAll('.tab').forEach((tab) => {
    tab.addEventListener('click', () => {
      document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
      document.querySelectorAll('.tab-page').forEach((p) => p.classList.remove('active'));
      tab.classList.add('active');
      $(`#tab-${tab.dataset.tab}`).classList.add('active');
    });
  });
}

async function commit(partial) {
  settings = await api.updateSettings(partial);
  renderGeneral();
  $('#p-enabled').checked = settings.enabled;
  $('#p-enabled-caption').textContent = enabledCaption();
}

const enabledCaption = () =>
  settings.enabled ? 'The trigger opens the ring.' : 'Paused — the trigger does nothing.';

// ---- General tab ------------------------------------------------------------------

function bindGeneral() {
  $('#g-enabled').addEventListener('change', (e) => commit({ enabled: e.target.checked }));
  $('#g-trigger').addEventListener('change', (e) => commit({ triggerButton: Number(e.target.value) }));
  $('#g-size').addEventListener('change', (e) => commit({ defaultRingSize: e.target.value }));
  $('#g-labels').addEventListener('change', (e) => commit({ showLabels: e.target.checked }));
  $('#g-fullscreen').addEventListener('change', (e) => commit({ suppressInFullscreen: e.target.checked }));
  $('#g-timeout').addEventListener('change', (e) => {
    const v = Math.min(60, Math.max(1, Math.round(Number(e.target.value) || 10)));
    e.target.value = v;
    commit({ scriptTimeoutSeconds: v });
  });
  $('#g-preview').addEventListener('click', () => api.preview());
  $('#g-record').addEventListener('click', () => {
    const btn = $('#g-record');
    if (recording) { // toggle = cancel an in-flight recording
      cancelRecording();
      return;
    }
    recording = true;
    btn.textContent = 'Press a button… (click to cancel)';
    $('#g-record-hint').textContent = 'Press the mouse button you want to use…';
    api.recordTrigger().then((button) => {
      if (!recording) return; // cancelled before the press landed
      recording = false;
      settings.triggerButton = button;
      btn.textContent = 'Record from mouse…';
      $('#g-record-hint').textContent = `Set to ${helpers.mouseButtonLabel(button)}`;
      renderGeneral();
    }).catch((err) => {
      recording = false;
      btn.textContent = 'Record from mouse…';
      $('#g-record-hint').textContent = `Recording failed: ${err?.message || err}`;
    });
  });
}

let recording = false;
function cancelRecording() {
  recording = false;
  api.cancelRecord();
  $('#g-record').textContent = 'Record from mouse…';
  $('#g-record-hint').textContent = 'Cancelled.';
}

function renderGeneral() {
  $('#g-enabled').checked = settings.enabled;
  $('#g-enabled-caption').textContent = enabledCaption();

  const trigger = $('#g-trigger');
  trigger.innerHTML = '';
  const choices = [0, 1, 2, 3, 4];
  if (!choices.includes(settings.triggerButton)) choices.push(settings.triggerButton);
  for (const n of choices) {
    const opt = el('option', null, helpers.mouseButtonLabel(n));
    opt.value = n;
    trigger.appendChild(opt);
  }
  trigger.value = settings.triggerButton;

  $('#g-size').value = settings.defaultRingSize;
  $('#g-labels').checked = settings.showLabels;
  $('#g-fullscreen').checked = settings.suppressInFullscreen;
  $('#g-timeout').value = settings.scriptTimeoutSeconds;

  const icon = $('#g-hook-icon');
  const status = $('#g-hook-status');
  if (hookInfo.canSuppress) {
    icon.className = 'ok';
    status.textContent = 'Mouse hook live — trigger presses are captured and suppressed.';
  } else if (hookInfo.armed) {
    icon.className = 'warn';
    status.textContent = 'Listen-only fallback — the ring works, but the trigger press also reaches apps.';
  } else {
    icon.className = 'bad';
    status.textContent = 'Mouse hook NOT installed — the trigger does nothing. Try Re-arm from the tray.';
  }
}

// ---- Profiles tab ------------------------------------------------------------------

async function renderProfiles(profiles) {
  profiles = profiles || (await api.listProfiles());
  $('#p-enabled').checked = settings.enabled;
  $('#p-enabled-caption').textContent = enabledCaption();

  const list = $('#profile-list');
  list.innerHTML = '';
  for (const profile of profiles) {
    const row = el('div', 'profile-row' + (profile.isEnabled ? '' : ' disabled'));

    if (profile.isDefault) {
      row.appendChild(el('span', 'lock', '🔒'));
    } else {
      const toggle = el('input', 'switch mini');
      toggle.type = 'checkbox';
      toggle.checked = profile.isEnabled;
      toggle.addEventListener('change', async () => {
        const updated = await api.setProfileEnabled(profile, toggle.checked);
        renderProfiles(updated);
      });
      row.appendChild(toggle);
    }

    const meta = el('div');
    meta.style.flex = '1';
    meta.appendChild(el('div', 'profile-name', profile.name));
    meta.appendChild(el('div', 'profile-sub',
      profile.bundleId ?? (profile.isDefault ? 'fallback · default' : `fallback · ${profile.category}`)));
    row.appendChild(meta);

    row.appendChild(el('span', 'badge', profile.source));

    const edit = el('button', 'icon-btn', '✏️');
    edit.title = 'Edit';
    edit.addEventListener('click', async () => {
      const draft = await api.editableCopy(profile);
      openProfileEditor(draft, false);
    });
    row.appendChild(edit);

    if (profile._isUserProfile) {
      const del = el('button', 'icon-btn danger', '🗑️');
      del.title = 'Delete';
      del.addEventListener('click', async () => {
        const updated = await api.deleteProfile(profile.id);
        renderProfiles(updated);
      });
      row.appendChild(del);
    }
    list.appendChild(row);
  }
}

// script runs at end of body — DOM is parsed, bind directly
$('#p-enabled').addEventListener('change', (e) => commit({ enabled: e.target.checked }));
$('#p-new').addEventListener('click', () => {
  openAppPicker(async (name, appId) => {
    const draft = await api.newProfile(name, appId);
    openProfileEditor(draft, true);
  });
});
$('#p-preview').addEventListener('click', () => api.preview(6000));

// ---- modal helpers ------------------------------------------------------------------

function openModal(buildBody) {
  const backdrop = el('div', 'modal-backdrop');
  const modal = el('div', 'modal');
  backdrop.appendChild(modal);
  $('#modal-root').appendChild(backdrop);
  const close = () => backdrop.remove();
  backdrop.addEventListener('mousedown', (e) => { if (e.target === backdrop) close(); });
  buildBody(modal, close);
  return close;
}

// ---- profile editor ------------------------------------------------------------------

function openProfileEditor(draft, isNew) {
  openModal((modal, close) => {
    const header = el('div', 'modal-header');
    header.appendChild(el('h2', null, isNew ? 'New Profile' : 'Edit Profile'));
    const previewBtn = el('button', 'btn', 'Preview');
    previewBtn.title = 'Save and show the ring';
    previewBtn.addEventListener('click', async () => {
      await api.saveProfile(draft);
      api.preview(6000);
    });
    header.appendChild(previewBtn);
    modal.appendChild(header);

    const body = el('div', 'modal-body');
    modal.appendChild(body);

    const render = () => {
      body.innerHTML = '';

      // name
      const fName = el('div', 'field');
      fName.appendChild(el('label', null, 'Name'));
      const name = el('input');
      name.type = 'text';
      name.value = draft.name;
      name.addEventListener('input', () => { draft.name = name.value; });
      fName.appendChild(name);
      body.appendChild(fName);

      // target app
      if (!draft.isDefault) {
        const fApp = el('div', 'field');
        fApp.appendChild(el('label', null, 'Target app'));
        const row = el('div', 'row');
        row.appendChild(el('span', 'caption', draft.bundleId ?? '—'));
        row.appendChild(el('span', 'spacer'));
        const choose = el('button', 'btn', 'Choose app…');
        choose.addEventListener('click', () => openAppPicker((n, appId) => {
          draft.bundleId = appId;
          if (!draft.name || isNew) draft.name = n;
          render();
        }));
        row.appendChild(choose);
        fApp.appendChild(row);
        fApp.appendChild(el('p', 'caption', `Category: ${draft.category}`));
        body.appendChild(fApp);
      }

      // size + slots
      const fGeo = el('div', 'field');
      const geoRow = el('div', 'row');
      geoRow.appendChild(segmented(
        [['small', 'S'], ['medium', 'M'], ['large', 'L']],
        draft.ringSize,
        (v) => { draft.ringSize = v; }
      ));
      geoRow.appendChild(el('span', 'spacer'));
      geoRow.appendChild(segmented(
        helpers.VALID_SLOT_COUNTS.map((n) => [String(n), `${n}`]),
        String(draft.slotCount),
        (v) => { draft.slotCount = Number(v); render(); }
      ));
      fGeo.appendChild(geoRow);
      body.appendChild(fGeo);

      // enabled
      if (!draft.isDefault) {
        const fEn = el('label', 'row');
        fEn.appendChild(el('span', 'row-label', 'Profile enabled'));
        const sw = el('input', 'switch');
        sw.type = 'checkbox';
        sw.checked = draft.isEnabled;
        sw.addEventListener('change', () => { draft.isEnabled = sw.checked; });
        fEn.appendChild(sw);
        body.appendChild(fEn);
      }

      // slot grid
      const fSlots = el('div', 'field');
      fSlots.appendChild(el('label', null, 'Slots — tap to edit'));
      const grid = el('div', 'slot-grid');
      for (let pos = 0; pos < draft.slotCount; pos++) {
        const slot = draft.slots.find((s) => s.position === pos) || helpers.emptySlot(pos);
        const hasAction = slot.action != null;
        const cell = el('button', 'slot-cell' + (!slot.isEnabled && hasAction ? ' dimmed' : ''));
        const glyph = el('span', 'glyph', helpers.iconGlyph(hasAction ? (slot.icon || 'circle.fill') : 'plus'));
        cell.appendChild(glyph);
        const meta = el('span', 'meta');
        meta.appendChild(el('div', 't', slot.label || 'Empty'));
        meta.appendChild(el('div', 'd', hasAction ? helpers.describeAction(slot.action) : 'tap to add'));
        cell.appendChild(meta);
        cell.appendChild(el('span', 'num', String(pos + 1)));
        cell.addEventListener('click', () => openSlotEditor(slot, {
          onSave: (updated) => {
            draft.slots = draft.slots.filter((s) => s.position !== updated.position);
            draft.slots.push(updated);
            draft.slots.sort((a, b) => a.position - b.position);
            render();
          },
          onClear: () => {
            draft.slots = draft.slots.filter((s) => s.position !== pos);
            render();
          },
        }));
        grid.appendChild(cell);
      }
      fSlots.appendChild(grid);
      body.appendChild(fSlots);
    };
    render();

    const footer = el('div', 'modal-footer');
    const cancel = el('button', 'btn', 'Cancel');
    cancel.addEventListener('click', close);
    const save = el('button', 'btn primary', 'Save');
    save.addEventListener('click', async () => {
      const updated = await api.saveProfile(draft);
      renderProfiles(updated);
      close();
    });
    footer.appendChild(cancel);
    footer.appendChild(save);
    modal.appendChild(footer);
  });
}

function segmented(options, value, onChange) {
  const wrap = el('span', 'segmented');
  for (const [v, label] of options) {
    const btn = el('button', v === value ? 'active' : '', label);
    btn.addEventListener('click', () => {
      wrap.querySelectorAll('button').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      onChange(v);
    });
    wrap.appendChild(btn);
  }
  return wrap;
}

// ---- slot editor ------------------------------------------------------------------

function openSlotEditor(slot, { onSave, onClear }) {
  const draft = structuredClone(slot);
  openModal((modal, close) => {
    const header = el('div', 'modal-header');
    header.appendChild(el('h2', null, `Slot ${draft.position + 1}`));
    const clear = el('button', 'btn danger', 'Clear');
    clear.title = 'Empty this slot';
    clear.addEventListener('click', () => { onClear(); close(); });
    header.appendChild(clear);
    modal.appendChild(header);

    const body = el('div', 'modal-body');
    modal.appendChild(body);

    // label
    const fLabel = el('div', 'field');
    fLabel.appendChild(el('label', null, 'Label'));
    const label = el('input');
    label.type = 'text';
    label.value = draft.label;
    label.addEventListener('input', () => { draft.label = label.value; });
    fLabel.appendChild(label);
    body.appendChild(fLabel);

    // icon
    const fIcon = el('div', 'field');
    fIcon.appendChild(el('label', null, 'Icon'));
    const iconRow = el('div', 'row');
    const preview = el('span', 'glyph', helpers.iconGlyph(draft.icon || 'questionmark'));
    preview.style.cssText = 'width:30px;height:30px;display:inline-flex;align-items:center;justify-content:center;background:var(--card-2);border-radius:7px;';
    const iconInput = el('input');
    iconInput.type = 'text';
    iconInput.placeholder = 'Symbol name';
    iconInput.value = draft.icon;
    iconInput.style.flex = '1';
    iconInput.addEventListener('input', () => {
      draft.icon = iconInput.value;
      preview.textContent = helpers.iconGlyph(draft.icon || 'questionmark');
      // keep the curated grid highlight in sync with free-text entry
      grid.querySelectorAll('.icon-cell').forEach((c) =>
        c.classList.toggle('selected', c.title === draft.icon));
    });
    iconRow.appendChild(preview);
    iconRow.appendChild(iconInput);
    fIcon.appendChild(iconRow);
    const grid = el('div', 'icon-grid');
    for (const name of CURATED_SYMBOLS) {
      const cell = el('button', 'icon-cell' + (draft.icon === name ? ' selected' : ''), helpers.iconGlyph(name));
      cell.title = name;
      cell.addEventListener('click', () => {
        draft.icon = name;
        iconInput.value = name;
        preview.textContent = helpers.iconGlyph(name);
        grid.querySelectorAll('.icon-cell').forEach((c) => c.classList.remove('selected'));
        cell.classList.add('selected');
      });
      grid.appendChild(cell);
    }
    fIcon.appendChild(grid);
    body.appendChild(fIcon);

    // color
    const fColor = el('div', 'field');
    fColor.appendChild(el('label', null, 'Color'));
    const swatches = el('div', 'swatches');
    const COLOR_HEX = {
      blue: '#0A84FF', purple: '#BF5AF2', pink: '#FF375F', red: '#FF453A', orange: '#FF9F0A',
      yellow: '#FFD60A', green: '#30D158', gray: '#8E8E93', teal: '#40C8E0', indigo: '#5E5CE6',
    };
    for (const c of helpers.SLOT_COLORS) {
      const sw = el('button', 'swatch' + (draft.color === c ? ' selected' : ''));
      sw.style.background = COLOR_HEX[c];
      sw.title = c;
      sw.addEventListener('click', () => {
        draft.color = c;
        swatches.querySelectorAll('.swatch').forEach((s) => s.classList.remove('selected'));
        sw.classList.add('selected');
      });
      swatches.appendChild(sw);
    }
    fColor.appendChild(swatches);
    body.appendChild(fColor);

    // enabled
    const fEn = el('label', 'row');
    fEn.appendChild(el('span', 'row-label', 'Enabled'));
    const sw = el('input', 'switch');
    sw.type = 'checkbox';
    sw.checked = draft.isEnabled;
    sw.addEventListener('change', () => { draft.isEnabled = sw.checked; });
    fEn.appendChild(sw);
    body.appendChild(fEn);

    // action editor
    const fAction = el('div', 'field');
    fAction.appendChild(el('label', null, 'Action'));
    const actionHost = el('div');
    fAction.appendChild(actionHost);
    body.appendChild(fAction);
    const getAction = buildActionEditor(actionHost, draft.action ?? null);

    const footer = el('div', 'modal-footer');
    const cancel = el('button', 'btn', 'Cancel');
    cancel.addEventListener('click', close);
    const save = el('button', 'btn primary', 'Save');
    save.addEventListener('click', () => {
      if (!draft.icon) draft.icon = 'circle.fill'; // mac parity
      const action = getAction();
      if (action == null) delete draft.action;
      else draft.action = action;
      onSave(draft);
      close();
    });
    footer.appendChild(cancel);
    footer.appendChild(save);
    modal.appendChild(footer);
  });
}

// ---- action editor (returns a () => wire-format-action|null getter) ----------------

function buildActionEditor(host, initial) {
  const KINDS = [
    ['none', 'Nothing'],
    ['keyboardShortcut', 'Keyboard Shortcut'],
    ['launchApplication', 'Launch App'],
    ['openURL', 'Open URL'],
    ['systemAction', 'System Action'],
    ['shellScript', 'PowerShell Script'],
    ['textSnippet', 'Type Text'],
    ['openFile', 'Open File/Folder'],
    ['advanced', 'Advanced (JSON only)'],
  ];

  // decompose
  const state = {
    kind: 'none', keyChar: 'c', useSpecialKey: false, specialKey: 'enter',
    modCtrl: true, modShift: false, modAlt: false,
    appId: '', urlString: 'https://', systemAction: 'screenshotArea',
    text: '', advancedAction: null,
  };
  if (initial && typeof initial === 'object') {
    const kind = Object.keys(initial)[0];
    const v = initial[kind];
    switch (kind) {
      case 'keyboardShortcut': {
        state.kind = kind;
        const key = v._0 || {};
        if (key.type === 'special') { state.useSpecialKey = true; state.specialKey = key.special; }
        else { state.useSpecialKey = false; state.keyChar = key.character || 'c'; }
        const mods = v.modifiers || [];
        state.modCtrl = mods.includes('control') || mods.includes('command');
        state.modShift = mods.includes('shift');
        state.modAlt = mods.includes('option');
        break;
      }
      case 'launchApplication': state.kind = kind; state.appId = v.bundleIdentifier || ''; break;
      case 'openURL': state.kind = kind; state.urlString = v._0 || 'https://'; break;
      case 'systemAction': state.kind = kind; state.systemAction = v._0 || 'screenshotArea'; break;
      case 'shellScript': state.kind = kind; state.text = v._0 || ''; break;
      case 'textSnippet': state.kind = kind; state.text = v._0 || ''; break;
      case 'openFile': state.kind = kind; state.text = v._0 || ''; break;
      default: state.kind = 'advanced'; state.advancedAction = initial; break;
    }
  }

  const recompose = () => {
    switch (state.kind) {
      case 'none': return null;
      case 'keyboardShortcut': {
        const mods = [];
        if (state.modCtrl) mods.push('control');
        if (state.modShift) mods.push('shift');
        if (state.modAlt) mods.push('option');
        const key = state.useSpecialKey
          ? { type: 'special', special: state.specialKey }
          : { type: 'character', character: (state.keyChar || 'c').slice(-1) };
        return { keyboardShortcut: { _0: key, modifiers: mods } };
      }
      case 'launchApplication': return { launchApplication: { bundleIdentifier: state.appId } };
      case 'openURL': return { openURL: { _0: state.urlString } };
      case 'systemAction': return { systemAction: { _0: state.systemAction } };
      case 'shellScript': return { shellScript: { _0: state.text } };
      case 'textSnippet': return { textSnippet: { _0: state.text } };
      case 'openFile': return { openFile: { _0: state.text } };
      case 'advanced': return state.advancedAction;
      default: return null;
    }
  };

  const render = () => {
    host.innerHTML = '';
    const select = el('select');
    for (const [v, label] of KINDS) {
      const opt = el('option', null, label);
      opt.value = v;
      select.appendChild(opt);
    }
    select.value = state.kind;
    select.style.marginBottom = '10px';
    select.addEventListener('change', () => { state.kind = select.value; render(); });
    host.appendChild(select);

    const form = el('div');
    host.appendChild(form);

    switch (state.kind) {
      case 'none':
        form.appendChild(el('p', 'caption', "This slot does nothing — it shows greyed out and can't be selected."));
        break;
      case 'keyboardShortcut': {
        const mods = el('div', 'mod-toggles');
        for (const [key, label] of [['modCtrl', 'Ctrl'], ['modShift', 'Shift'], ['modAlt', 'Alt']]) {
          const b = el('button', state[key] ? 'active' : '', label);
          b.addEventListener('click', () => { state[key] = !state[key]; b.classList.toggle('active'); updatePreview(); });
          mods.appendChild(b);
        }
        form.appendChild(mods);

        const specialRow = el('label', 'row');
        specialRow.appendChild(el('span', 'row-label', 'Use a named key (arrows, F-keys, Enter…)'));
        const specialSw = el('input', 'switch');
        specialSw.type = 'checkbox';
        specialSw.checked = state.useSpecialKey;
        specialSw.addEventListener('change', () => { state.useSpecialKey = specialSw.checked; render(); });
        specialRow.appendChild(specialSw);
        form.appendChild(specialRow);

        if (state.useSpecialKey) {
          const sel = el('select');
          for (const k of helpers.SPECIAL_KEYS) {
            const opt = el('option', null, k);
            opt.value = k;
            sel.appendChild(opt);
          }
          sel.value = state.specialKey;
          sel.addEventListener('change', () => { state.specialKey = sel.value; updatePreview(); });
          form.appendChild(sel);
        } else {
          const input = el('input');
          input.type = 'text';
          input.placeholder = 'Key (single character)';
          input.maxLength = 1;
          input.style.width = '180px';
          input.value = state.keyChar;
          input.addEventListener('input', () => { state.keyChar = input.value.slice(-1); updatePreview(); });
          form.appendChild(input);
        }
        const previewLine = el('p', 'caption');
        form.appendChild(previewLine);
        const updatePreview = () => {
          previewLine.textContent = `Preview: ${helpers.describeAction(recompose()) ?? '—'}`;
        };
        updatePreview();
        break;
      }
      case 'launchApplication': {
        const input = el('input');
        input.type = 'text';
        input.placeholder = 'Executable (e.g. code.exe) or full path';
        input.value = state.appId;
        input.style.width = '100%';
        input.addEventListener('input', () => { state.appId = input.value; });
        form.appendChild(input);
        break;
      }
      case 'openURL': {
        const input = el('input');
        input.type = 'text';
        input.placeholder = 'URL';
        input.value = state.urlString;
        input.style.width = '100%';
        input.addEventListener('input', () => { state.urlString = input.value; });
        form.appendChild(input);
        break;
      }
      case 'systemAction': {
        const sel = el('select');
        for (const a of helpers.SYSTEM_ACTIONS) {
          const opt = el('option', null, SYSTEM_ACTION_LABELS[a] || a);
          opt.value = a;
          sel.appendChild(opt);
        }
        sel.value = state.systemAction;
        sel.addEventListener('change', () => { state.systemAction = sel.value; });
        form.appendChild(sel);
        break;
      }
      case 'shellScript': {
        const ta = el('textarea');
        ta.value = state.text;
        ta.addEventListener('input', () => { state.text = ta.value; });
        form.appendChild(ta);
        form.appendChild(el('p', 'caption', 'Runs via PowerShell with a timeout. Obvious destructive commands are refused.'));
        break;
      }
      case 'textSnippet': {
        const input = el('input');
        input.type = 'text';
        input.placeholder = 'Text to type';
        input.value = state.text;
        input.style.width = '100%';
        input.addEventListener('input', () => { state.text = input.value; });
        form.appendChild(input);
        break;
      }
      case 'openFile': {
        const row = el('div', 'row');
        const input = el('input');
        input.type = 'text';
        input.placeholder = 'File or folder path';
        input.value = state.text;
        input.style.flex = '1';
        input.addEventListener('input', () => { state.text = input.value; });
        row.appendChild(input);
        const choose = el('button', 'btn', 'Choose…');
        choose.addEventListener('click', async () => {
          const p = await api.chooseFile();
          if (p) { state.text = p; input.value = p; }
        });
        row.appendChild(choose);
        form.appendChild(row);
        break;
      }
      case 'advanced':
        form.appendChild(el('p', 'caption',
          "Workflows, AppleScript/Shortcuts (mac-only) and MCP actions aren't editable here — edit profiles.json directly. The existing action is preserved."));
        break;
    }
  };
  render();
  return recompose;
}

// ---- app picker ------------------------------------------------------------------

function openAppPicker(onPick) {
  openModal(async (modal, close) => {
    const header = el('div', 'modal-header');
    header.appendChild(el('h2', null, 'Choose an app'));
    const cancel = el('button', 'btn', 'Cancel');
    cancel.addEventListener('click', close);
    header.appendChild(cancel);
    modal.appendChild(header);

    const body = el('div', 'modal-body');
    modal.appendChild(body);

    const search = el('input', 'app-search');
    search.type = 'text';
    search.placeholder = 'Search apps…';
    body.appendChild(search);

    const list = el('div', 'app-list');
    body.appendChild(list);

    const apps = await api.selectableApps();
    const renderList = () => {
      const q = search.value.trim().toLowerCase();
      list.innerHTML = '';
      const filtered = q
        ? apps.filter((a) => a.name.toLowerCase().includes(q) || a.appId.toLowerCase().includes(q))
        : apps;
      for (const app of filtered) {
        const item = el('button', 'app-item');
        item.appendChild(el('div', 'n', app.name));
        item.appendChild(el('div', 'b', app.appId));
        item.addEventListener('click', () => { onPick(app.name, app.appId); close(); });
        list.appendChild(item);
      }
      if (filtered.length === 0) list.appendChild(el('div', 'app-item', 'No matches'));
    };
    search.addEventListener('input', renderList);
    renderList();

    const manual = el('div', 'manual-row');
    const manualInput = el('input');
    manualInput.type = 'text';
    manualInput.placeholder = '…or type an exe name (e.g. someapp.exe)';
    const use = el('button', 'btn', 'Use');
    use.addEventListener('click', () => {
      const id = manualInput.value.trim().toLowerCase();
      if (!id) return;
      const display = id.replace(/\.exe$/, '');
      onPick(display.charAt(0).toUpperCase() + display.slice(1), id);
      close();
    });
    manual.appendChild(manualInput);
    manual.appendChild(use);
    body.appendChild(manual);
  });
}

init();
