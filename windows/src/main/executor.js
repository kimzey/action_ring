'use strict';
// ActionExecutor — port of Execution/ActionExecutor.swift for Windows.
//
// Differences forced by the platform (per port spec):
//  * Key synthesis: Win32 has no per-event modifier flags, so we post
//    modifiers-down → key-down → key-up → modifiers-up via SendInput
//    (behavioral equivalence with the mac flags-on-event idiom).
//  * System actions map to their Windows equivalents (table below).
//  * appleScript / shortcutsApp are macOS-only → clean failure result.
//
// Results mirror ActionExecutorResult: { ok: true } | { ok: false, error }.

const { shell } = require('electron');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');

const { actionKind } = require('../shared/models');
const { resolveKeyCode } = require('../shared/keymap');
const input = require('./win32/input');
const C = require('./win32/winconst');
const { runScript } = require('./scriptRunner');

const WORKFLOW_STEP_GAP_MS = 30; // parity: 30ms between workflow steps

const ok = () => ({ ok: true });
const fail = (error) => ({ ok: false, error });

// openURL: only schemes that can't drive a local handler into executing things.
const URL_SCHEME_ALLOWLIST = new Set(['http', 'https', 'mailto']);

// openFile: extensions the Windows shell would EXECUTE rather than just open.
const EXECUTABLE_EXTENSIONS = new Set([
  '.exe', '.com', '.scr', '.pif', '.bat', '.cmd', '.lnk', '.ps1', '.psm1',
  '.vbs', '.vbe', '.js', '.jse', '.wsf', '.wsh', '.msi', '.msp', '.cpl',
  '.hta', '.reg', '.jar', '.gadget', '.inf', '.scf', '.url',
]);

// ---- script safety (ScriptRunner.validateShellScript parity + Windows set) -----
//
// NOTE: this denylist is a COARSE GUARDRAIL, not a security boundary. It only
// blocks the exact listed literals — trivially bypassed by case/spacing/encoding.
// The real trust boundary is the profile source: scripts come only from the
// user's own profiles.json. Treat shellScript actions from imported/community
// profile packs as untrusted and review the script text before running them.

const DANGEROUS_PATTERNS = [
  // mac list (kept verbatim — harmless to retain cross-platform)
  'rm -rf /', 'rm -rf ~', 'rm -fr /', 'rm -fr ~',
  'rm -rf /usr', 'rm -rf /bin', 'rm -rf /sbin', 'rm -rf /etc',
  'rm -rf /var', 'rm -rf /system', 'rm -rf /library',
  'dd if=/dev/zero', 'dd if=/dev/random', 'dd if=/dev/urandom',
  ':(){ :|:& };:', 'mkfs', '> /dev/sda', 'format c:',
  // Windows-destructive additions
  'del /s /q c:', 'del /f /s /q c:', 'rd /s /q c:', 'rmdir /s /q c:',
  'remove-item -recurse -force c:', 'remove-item c:\\ -recurse',
  'diskpart', 'cipher /w', 'reg delete hklm', 'vssadmin delete shadows',
  'bcdedit /deletevalue', 'format d:', 'format e:',
];

function validateScript(script) {
  const trimmed = String(script ?? '').trim();
  if (trimmed === '') return { isValid: false, error: 'Script is empty' };
  const lower = trimmed.toLowerCase();
  for (const pattern of DANGEROUS_PATTERNS) {
    if (lower.includes(pattern)) {
      return { isValid: false, error: `Refused: contains dangerous command pattern '${pattern}'` };
    }
  }
  if (lower.includes('chmod') && lower.includes('777')) {
    return { isValid: false, error: 'Refused: chmod 777 is not allowed' };
  }
  return { isValid: true, error: '' };
}

// ---- system actions --------------------------------------------------------------

let LockWorkStation = null;
function lockWorkStation() {
  if (process.platform !== 'win32') return false;
  if (!LockWorkStation) {
    const koffi = require('koffi');
    LockWorkStation = koffi.load('user32.dll').func('bool LockWorkStation()');
  }
  return LockWorkStation();
}

const VK_SNAPSHOT = 0x2c;

class ActionExecutor {
  /** @param {{ timeoutSeconds?: number }} options */
  constructor(options = {}) {
    this.timeoutSeconds = options.timeoutSeconds ?? 10;
  }

  /** @returns {Promise<{ok:boolean, error?:string}>} */
  async execute(action) {
    const kind = actionKind(action);
    if (!kind) return fail('Invalid action');
    const v = action[kind];
    try {
      switch (kind) {
        case 'keyboardShortcut': return this._keyboardShortcut(v._0, v.modifiers || []);
        case 'launchApplication': return this._launchApplication(v.bundleIdentifier);
        case 'openURL': return this._openURL(v._0);
        case 'systemAction': return this._systemAction(v._0);
        case 'shellScript': return this._shellScript(v._0);
        case 'appleScript': return fail('AppleScript actions are macOS-only');
        case 'shortcutsApp': return fail('Apple Shortcuts are macOS-only');
        case 'textSnippet': return this._typeText(v._0);
        case 'openFile': return this._openFile(v._0);
        case 'workflow': return this._workflow(v._0 || []);
        case 'mcpToolCall':
        case 'mcpWorkflow': return fail('Not implemented');
        default: return fail(`Unknown action: ${kind}`);
      }
    } catch (err) {
      return fail(err.message || String(err));
    }
  }

  // ---- per-kind handlers ----------------------------------------------------------

  _keyboardShortcut(keyCode, modifiers) {
    const resolved = resolveKeyCode(keyCode);
    if (!resolved) {
      // Unmapped character → Unicode typing fallback (mac parity).
      if (keyCode?.type === 'character' && keyCode.character) {
        return this._typeText(String(keyCode.character));
      }
      return fail('Unmapped key');
    }
    const mods = {
      // command (mac) and control both mean Ctrl on Windows; option = Alt.
      ctrl: modifiers.includes('command') || modifiers.includes('control'),
      alt: modifiers.includes('option'),
      shift: modifiers.includes('shift') || resolved.needsShift,
      win: false,
    };
    if (!input.available()) return fail('Key injection unavailable on this platform');
    return input.sendShortcut(resolved.vk, mods) ? ok() : fail('SendInput failed');
  }

  _typeText(text) {
    if (typeof text !== 'string' || text.length === 0) return ok();
    if (!input.available()) return fail('Key injection unavailable on this platform');
    return input.typeText(text) ? ok() : fail('SendInput failed');
  }

  async _launchApplication(id) {
    if (!id) return fail('Empty application id');
    // id may be an exe name ("code.exe" — resolved via App Paths / PATH) or a
    // full path. The id comes from profile JSON, so treat it as untrusted:
    // strict character allowlist, then hand it to cmd's `start` as a single
    // quoted argument (no interpolation of cmd metacharacters survives).
    if (process.platform !== 'win32') {
      return fail('App launch is Windows-only in this build');
    }
    const cleaned = String(id).trim();
    if (!/^[\w .\-\\/:()+~]+$/.test(cleaned) || /[&|<>^%!]/.test(cleaned)) {
      return fail(`Invalid application id: ${id}`);
    }
    // Refuse UNC paths — a profile pack must not pull a binary off a remote share.
    if (/^\\\\/.test(cleaned) || /^\/\//.test(cleaned)) {
      return fail('Refused UNC path (remote executables are not allowed)');
    }
    return new Promise((resolve) => {
      // spawn-style arg array; windowsVerbatimArguments keeps cmd from re-parsing
      const { execFile } = require('node:child_process');
      execFile('cmd.exe', ['/d', '/s', '/c', `start "" "${cleaned}"`], {
        windowsHide: true,
        windowsVerbatimArguments: true,
      }, (err) => resolve(err ? fail(`App not found: ${cleaned}`) : ok()));
    });
  }

  async _openURL(url) {
    if (typeof url !== 'string') return fail('Invalid URL');
    // Scheme allowlist — a profile must not be able to fire file:, smb:, shell:,
    // search-ms:, ms-*: or other locally-dangerous handlers via the ring.
    const scheme = (url.split(':', 1)[0] || '').toLowerCase();
    if (!URL_SCHEME_ALLOWLIST.has(scheme)) {
      return fail(`Refused URL scheme: ${scheme || '(none)'} (only http/https/mailto allowed)`);
    }
    await shell.openExternal(url);
    return ok();
  }

  async _openFile(p) {
    let expanded = String(p || '');
    if (expanded.startsWith('~')) expanded = path.join(os.homedir(), expanded.slice(1));
    expanded = expanded.replace(/%([^%]+)%/g, (m, name) => process.env[name] ?? m);
    // Re-validate AFTER expansion: openFile uses the shell, which would happily
    // execute a .exe/.bat/.lnk/etc. Treat the target as untrusted profile data
    // and refuse to "open" anything executable (parity-safe: mac NSWorkspace.open
    // on a doc is benign; here we must guard the shell-exec surface).
    const ext = path.extname(expanded).toLowerCase();
    if (EXECUTABLE_EXTENSIONS.has(ext)) {
      return fail(`Refused to open executable file type: ${ext} (use Launch App instead)`);
    }
    if (!fs.existsSync(expanded)) return fail(`File not found: ${expanded}`);
    const err = await shell.openPath(expanded);
    return err ? fail(`Failed to open: ${expanded} (${err})`) : ok();
  }

  async _shellScript(script) {
    const validation = validateScript(script);
    if (!validation.isValid) return fail(validation.error);
    const r = await runScript('powershell', script, this.timeoutSeconds * 1000);
    if (r.error && /timed out/.test(r.error)) return fail(`Script timed out after ${this.timeoutSeconds}s`);
    return r.ok ? ok() : fail(r.error || `Exit code ${r.code}`);
  }

  async _systemAction(name) {
    switch (name) {
      case 'volumeUp': return input.tapKey(C.VK_VOLUME_UP) ? ok() : fail('SendInput failed');
      case 'volumeDown': return input.tapKey(C.VK_VOLUME_DOWN) ? ok() : fail('SendInput failed');
      case 'mute': return input.tapKey(C.VK_VOLUME_MUTE) ? ok() : fail('SendInput failed');
      case 'mediaPlayPause': return input.tapKey(C.VK_MEDIA_PLAY_PAUSE) ? ok() : fail('SendInput failed');
      case 'mediaNext': return input.tapKey(C.VK_MEDIA_NEXT_TRACK) ? ok() : fail('SendInput failed');
      case 'mediaPrevious': return input.tapKey(C.VK_MEDIA_PREV_TRACK) ? ok() : fail('SendInput failed');
      case 'lockScreen': return lockWorkStation() ? ok() : fail('LockWorkStation failed');
      case 'screenshot': // full screen → file (Win+PrtScn)
        return input.sendShortcut(VK_SNAPSHOT, { win: true }) ? ok() : fail('SendInput failed');
      case 'screenshotArea': // snip overlay (Win+Shift+S)
        return input.sendShortcut(0x53 /* S */, { win: true, shift: true }) ? ok() : fail('SendInput failed');
      case 'missionControl': // Task View (Win+Tab)
        return input.sendShortcut(0x09 /* Tab */, { win: true }) ? ok() : fail('SendInput failed');
      case 'showDesktop': // Win+D
        return input.sendShortcut(0x44 /* D */, { win: true }) ? ok() : fail('SendInput failed');
      case 'launchpad': // Start menu ≈ Launchpad
        return input.sendShortcut(0x1b /* Esc */, { ctrl: true }) ? ok() : fail('SendInput failed');
      case 'notificationCenter': // Win+N (Windows 11)
        return input.sendShortcut(0x4e /* N */, { win: true }) ? ok() : fail('SendInput failed');
      case 'brightnessUp': return this._brightness(+10);
      case 'brightnessDown': return this._brightness(-10);
      case 'sleep':
        return this._shellScript('rundll32.exe powrprof.dll,SetSuspendState 0,1,0');
      default: return fail(`Unsupported system action: ${name}`);
    }
  }

  async _brightness(delta) {
    // Laptop panels only (WMI); external monitors don't expose this interface.
    const ps =
      '$b=(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightness).CurrentBrightness;' +
      `$n=[Math]::Max(0,[Math]::Min(100,$b+(${delta})));` +
      '(Get-WmiObject -Namespace root/WMI -Class WmiMonitorBrightnessMethods).WmiSetBrightness(1,$n)';
    const r = await runScript('powershell', ps, 5000);
    return r.ok ? ok() : fail('Brightness control unavailable on this display');
  }

  async _workflow(actions) {
    for (const step of actions) {
      const result = await this.execute(step);
      if (!result.ok) return result; // stop at first failure (mac parity)
      await new Promise((r) => setTimeout(r, WORKFLOW_STEP_GAP_MS));
    }
    return ok();
  }
}

module.exports = { ActionExecutor, validateScript, DANGEROUS_PATTERNS };
