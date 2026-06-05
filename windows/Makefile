# ActionRing for Windows — convenience targets.
#
# These are thin wrappers over the npm scripts in package.json. Every recipe is
# a single `npm` call (no shell builtins), so it behaves the same whether make
# runs it through cmd, PowerShell, or sh.
#
# ⚠ Windows doesn't ship `make`. If `make` isn't found, just run the npm command
#   shown next to each target below — e.g. `npm run pack` instead of `make pack`.
#   (Get make on Windows via: scoop install make  /  choco install make  /
#   it's bundled with Git Bash & MSYS2.)
#
#   make            show this help
#   make install    install dependencies          (npm install)
#   make run        start the tray app             (npm start)
#   make preview    preview the ring               (npm run preview)
#   make test       run unit tests                 (npm test)
#   make pack       portable build + release zip   (npm run pack)   ← recommended
#   make dist       NSIS installer (.exe)          (npm run dist)
#   make capture    snapshot ring.png              (npm run capture)
#   make clean      remove node_modules + dist     (npm run clean)

.PHONY: help install run start preview test pack dist capture clean

help:
	@echo ActionRing for Windows - run a target with make, or the npm command if you have no make:
	@echo   make install    npm install        install dependencies
	@echo   make run         npm start         start the tray app
	@echo   make preview     npm run preview   preview the ring
	@echo   make test        npm test          run unit tests
	@echo   make pack        npm run pack      portable build + zip  [recommended]
	@echo   make dist        npm run dist      NSIS installer .exe
	@echo   make capture     npm run capture   snapshot ring.png
	@echo   make clean       npm run clean     remove node_modules and dist

install:
	npm install

run start:
	npm start

preview:
	npm run preview

test:
	npm test

# Reliable distributable: portable folder + release-ready .zip via
# @electron/packager. Avoids electron-builder's one-time winCodeSign download.
pack:
	npm run pack

# NSIS installer. First run downloads ~150 MB of build tools (winCodeSign/nsis)
# from GitHub into a cache — slow once, fast after. See docs/RELEASES.md.
dist:
	npm run dist

capture:
	npm run capture

clean:
	npm run clean
