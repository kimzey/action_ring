'use strict';
// Shell-script execution — the Windows analog of the mac ScriptRunner
// (zsh / osascript). Windows flavors:
//   shellScript  → powershell.exe -NoProfile (closest to "run a script")
//   cmdScript    → cmd.exe /d /s /c          (for .bat-style one-liners)
//
// Same safety posture as the mac version: scripts come only from the user's
// own profiles.json, run detached from the UI, time-boxed, output captured
// but never parsed.

const { spawn } = require('node:child_process');

const DEFAULT_TIMEOUT_MS = 30_000;
const MAX_OUTPUT_BYTES = 64 * 1024;

/**
 * @param {'powershell'|'cmd'} flavor
 * @param {string} script
 * @returns {Promise<{ ok: boolean, code: number|null, output: string, error?: string }>}
 */
function runScript(flavor, script, timeoutMs = DEFAULT_TIMEOUT_MS) {
  return new Promise((resolve) => {
    if (typeof script !== 'string' || script.trim() === '') {
      resolve({ ok: false, code: null, output: '', error: 'empty script' });
      return;
    }

    let cmd, args;
    if (process.platform === 'win32') {
      if (flavor === 'cmd') {
        cmd = 'cmd.exe';
        args = ['/d', '/s', '/c', script];
      } else {
        cmd = 'powershell.exe';
        args = ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-Command', script];
      }
    } else {
      // Dev fallback on macOS so workflow testing is possible end-to-end.
      cmd = '/bin/zsh';
      args = ['-c', script];
    }

    let out = '';
    let settled = false;
    const child = spawn(cmd, args, { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });

    const finish = (result) => {
      if (settled) return;
      settled = true;
      clearTimeout(timer);
      resolve(result);
    };

    const timer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch { /* already dead */ }
      finish({ ok: false, code: null, output: out, error: `timed out after ${timeoutMs}ms` });
    }, timeoutMs);

    const collect = (chunk) => {
      if (out.length < MAX_OUTPUT_BYTES) out += chunk.toString('utf8');
    };
    child.stdout.on('data', collect);
    child.stderr.on('data', collect);

    child.on('error', (err) => finish({ ok: false, code: null, output: out, error: err.message }));
    child.on('close', (code) => finish({ ok: code === 0, code, output: out.slice(0, MAX_OUTPUT_BYTES) }));
  });
}

module.exports = { runScript, DEFAULT_TIMEOUT_MS };
