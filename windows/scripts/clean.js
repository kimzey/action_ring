'use strict';
// Cross-platform `clean` — remove node_modules and dist. Pure Node so it works
// identically in cmd, PowerShell, and sh (the Makefile `clean` quoting was
// shell-specific and broke on Windows).

const fs = require('node:fs');
const path = require('node:path');

const root = path.join(__dirname, '..');
for (const dir of ['node_modules', 'dist']) {
  fs.rmSync(path.join(root, dir), { recursive: true, force: true });
}
console.log('Cleaned node_modules and dist.');
