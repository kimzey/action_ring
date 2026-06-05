# ActionRing for Windows — dev/run convenience targets.
#
# Works with GNU Make on Windows (Git Bash, MSYS2, choco/scoop `make`) and on
# macOS/Linux for development. Every target just wraps an npm script, so if you
# don't have `make` you can run the npm command shown in each comment directly.
#
#   make            show this help
#   make install    install dependencies (run once)
#   make run        start the tray app (hold Button 4 to open the ring)
#   make preview    show the ring following your cursor (no trigger needed)
#   make test       run the unit-test suite
#   make dist       build the Windows installer (.exe) into ./dist
#   make capture    render the ring to ./ring.png (visual sanity check)
#   make clean      delete node_modules and ./dist

.PHONY: help install run start preview test dist capture clean

# Default: list the targets with their one-line descriptions.
# (Plain text only — no shell-special chars like parentheses in echo, so this
#  works under both /bin/sh and Windows cmd.)
help:
	@echo ActionRing for Windows - make targets:
	@echo   make install    install dependencies   runs npm install
	@echo   make run        start the tray app      runs npm start
	@echo   make preview    preview the ring        runs npm run preview
	@echo   make test       run unit tests          runs npm test
	@echo   make dist       build the installer     runs npm run dist
	@echo   make capture    snapshot ring.png       runs electron . --capture
	@echo   make clean      remove node_modules and dist

# Install dependencies. Run once after cloning (or after changing package.json).
install:
	npm install

# Start the tray app. Lives in the system tray (no window); hold the trigger
# button — default is the mouse side button (Button 4) — to open the ring.
run: start
start:
	npm start

# Show the ring centered on screen, following your cursor, for ~10s. Needs no
# mouse hook or permission — use it to confirm the look + tracking.
preview:
	npm run preview

# Run the unit tests (geometry, profile schema, resolution chain, keymap, …).
test:
	npm test

# Build a distributable NSIS installer (ActionRing-Setup-<version>.exe) in
# ./dist. Best run ON Windows; cross-building the installer from macOS needs
# extra tooling (wine), so prefer running this target on a Windows machine.
dist:
	npm run dist

# Dev aid: render the preview ring and save it to ./ring.png, then exit.
capture:
	npx electron . --capture ring.png

# Remove installed dependencies and build output (cross-platform via Node).
clean:
	node -e "const fs=require('fs');for(const d of ['node_modules','dist']){fs.rmSync(d,{recursive:true,force:true})}"
	@echo Cleaned node_modules and dist.
