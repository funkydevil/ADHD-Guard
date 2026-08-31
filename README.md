# ADHD Guard for macOS

ADHD Guard watches the frontmost application and, for supported browsers, the active tab. It gives unlisted activity a configurable grace period and then opens an always-on-top warning that repeats a sound and spoken phrase. Explicitly blocked rules alert immediately.

The optional idle mode also warns when a focused application is open but there has been no keyboard or mouse input for the configured duration.

## Included in this MVP

- Allowed and blocked application rules selected from installed `.app` bundles.
- Allowed and blocked website rules with subdomain matching.
- A configurable distraction grace period.
- Idle detection and a separate idle phrase.
- A compact, click-through focus banner across Spaces, a gentle reminder chime, and an optional spoken warning.
- A menu bar control plus a full SwiftUI dashboard.
- Three recent browser hosts for one-click blocking during the current app session.
- Local persistence in `UserDefaults`; active URLs and browsing history are not stored between launches.
- Safari, Google Chrome, Microsoft Edge, Brave, and Arc active-tab readers.

## Run in development

Requirements: macOS 13 or newer and Xcode Command Line Tools.

```bash
swift test
swift run ADHDGuard
```

Running the bare Swift Package is convenient for development, but macOS may attribute Automation permission to the launching terminal. For realistic permissions, build and launch the app bundle:

```bash
./scripts/build-app.sh
open build/ADHDGuard.app
```

On first browser inspection, accept the macOS Automation prompt. If it was denied, open **System Settings → Privacy & Security → Automation** and enable the relevant browser under ADHD Guard.

## Rule priority

1. ADHD Guard itself is always focused so its settings remain usable.
2. A blocked website wins and alerts immediately.
3. An allowed website counts as focused, even if the browser is not separately allowed.
4. When any allowed website exists, other readable browser sites use the grace period.
5. Blocked applications alert immediately; allowed applications are focused.
6. Everything else uses the grace period.
7. Idle warnings are evaluated only in a focused context.

Once a distraction warning starts, switching between blocked or unlisted apps and sites does not reset it. The warning stops only after ADHD Guard observes an allowed context.

If the browser URL cannot be read, ADHD Guard shows a permission warning and falls back to the application rule. It deliberately avoids a false alarm based only on missing Automation access.

## Current MVP limits

- This is a warning and accountability tool, not a hard blocker. It does not close apps, navigate tabs, or intercept network traffic.
- Browser URL support depends on each browser's AppleScript interface and macOS Automation permission.
- Rules are global. Named focus profiles and schedules are natural next steps.
- The app is ad-hoc signed by the build script for local use; distribution requires an Apple Developer ID, hardened runtime, notarization, and a release bundle identifier.
