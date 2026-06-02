.PHONY: build run check test bundle dmg install cert reset-perms clean

# Compile all targets (debug).
build:
	swift build

# Run the menu-bar app from the build dir (kills any stale instance first).
# Prefer `make install` for Accessibility persistence.
run:
	-killall ActionRing 2>/dev/null || true
	swift run ActionRing

# Run the dependency-free invariant checker (works without Xcode/XCTest).
check:
	swift run ARCheck

# Run the XCTest suite (requires a full Xcode toolchain).
test:
	swift test

# Assemble a signed ActionRing.app (release). Kills stale instances; uses the
# "ActionRing Dev" identity if present, else ad-hoc.
bundle:
	./Scripts/bundle.sh release

# Package a distributable ActionRing-<version>.dmg in ./dist for handing to
# other people (free path — they right-click → Open on first launch).
dmg:
	./Scripts/release.sh

# One-time: create a stable self-signed identity so the Accessibility grant
# survives rebuilds.
cert:
	./Scripts/dev-cert.sh

# Build the bundle, replace the copy in /Applications, and open it fresh.
install: bundle
	-killall ActionRing 2>/dev/null || true
	rm -rf /Applications/ActionRing.app
	cp -R ActionRing.app /Applications/
	open /Applications/ActionRing.app
	@echo "Opened from /Applications. Grant Accessibility to ActionRing, then use the trigger."

# Clear stale Accessibility grants for ActionRing (use if the toggle is on but
# the trigger still doesn't work after an ad-hoc rebuild).
reset-perms:
	-killall ActionRing 2>/dev/null || true
	tccutil reset Accessibility com.actionring.app || true
	@echo "Cleared. Reopen ActionRing and grant Accessibility again."

clean:
	swift package clean
	rm -rf .build ActionRing.app dist
