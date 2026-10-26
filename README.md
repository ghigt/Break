# Break

A tiny macOS menu bar app that enforces a 5-minute break every 25 minutes.

- **Menu bar icon**: a cup inside a ring of five segments that fill up as the break approaches.
- **Warning** one minute before the break: a floating panel with a countdown, plus *Snooze* (3 min) and *Break now* buttons.
- **Break**: every display is covered; the Dock, the menu bar, ⌘Tab, ⌘Q and Force Quit are disabled. Skipping the break requires **holding** the button for 3 seconds.
- **Break over**: the screen stays locked until you click “Resume” (or press ↩︎), which starts a new 25-minute cycle.
- **Disable** from the menu bar for 30 minutes, 1 hour, 2 hours, until tomorrow, or until you turn it back on.
- If the session is locked or the Mac sleeps for longer than a break, the 25-minute cycle starts over.
- Durations, sounds and launch at login are configurable in **Settings…**.
- Available in English and French (follows the system language).

Requirements: macOS 14 (Sonoma) or later, Apple Silicon or Intel.

## Install (no admin rights needed)

1. Copy `Break.zip` to the Mac and unzip it.
2. In Terminal:

   ```sh
   bash ~/Downloads/Break/install.sh
   ```

The script copies `Break.app` into `~/Applications` (the user’s own Applications folder), lifts the Gatekeeper quarantine (the app is not notarized) and launches it. Nothing else is installed.

Uninstall: quit Break from the menu bar, then delete `~/Applications/Break.app`.

## Build

Requires Xcode or the Command Line Tools (`xcode-select --install`):

```sh
./scripts/build.sh      # → build/Break.app and build/Break.zip
./scripts/install.sh    # installs build/Break.app into ~/Applications
```

With Xcode the app is universal (Apple Silicon + Intel); with only the Command Line Tools it is built for the current Mac’s architecture.

Run the tests:

```sh
swift test
```

To run a full cycle quickly, make a “minute” shorter than 60 seconds:

```sh
BREAK_SECONDS_PER_MINUTE=2 BREAK_DEBUG=1 build/Break.app/Contents/MacOS/Break
```

## Localization

UI strings are written in English in the code; translations live in `Resources/<language>.lproj/Localizable.strings`.
