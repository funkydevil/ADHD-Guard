# ADHD Guard for macOS

ADHD Guard watches the frontmost application and, for supported browsers, the active tab. Websites in the outside-focus list and applications outside the focus-app list receive a configurable grace period before an always-on-top warning repeats a sound and spoken phrase.

The optional idle mode also warns when a focused application is open but there has been no keyboard or mouse input for the configured duration.

## Included in this MVP

- A focus-app list selected from installed `.app` bundles.
- An outside-focus website list with subdomain matching.
- Supported browsers are focus apps by default; websites in the outside-focus list are still evaluated first.
- A configurable distraction grace period.
- Idle detection and a separate idle phrase.
- A compact, interactive focus banner across Spaces, a gentle reminder chime, and an optional spoken warning.
- Clicking a warning returns to the last focused app or browser tab; if that tab was closed, the saved in-memory URL opens in the same browser.
- A menu bar control plus a full SwiftUI dashboard.
- Three recent browser hosts for one-click addition to the outside-focus list during the current app session.
- Three recent active applications for one-click addition to the focus-app list during the current app session.
- Local persistence in `UserDefaults`; active URLs and browsing history are not stored between launches.
- Safari, Google Chrome, Microsoft Edge, Brave, and Arc active-tab readers.

## Run in development

Requirements: macOS 13 or newer and Xcode 14 or newer.

Open `ADHDGuard.xcodeproj`, select the `ADHDGuard` scheme, and run the app. You can also build and test it from Terminal:

```bash
xcodebuild -project ADHDGuard.xcodeproj -scheme ADHDGuard -destination 'platform=macOS' build
xcodebuild -project ADHDGuard.xcodeproj -scheme ADHDGuard -destination 'platform=macOS' test
```

`Start at login` uses the macOS 13+ Service Management API. For a daily-use build, place `ADHDGuard.app` in `/Applications` before enabling it; an Xcode DerivedData build can be moved or replaced between launches and is not a stable login-item location.

On first browser inspection, accept the macOS Automation prompt. If it was denied, open **System Settings → Privacy & Security → Automation** and enable the relevant browser under ADHD Guard.

## Rule priority

1. ADHD Guard itself is always focused so its settings remain usable.
2. A website in the outside-focus list uses the configured grace period.
3. An application in the focus-app list is focused.
4. Every other application uses the configured grace period.
5. Idle warnings are evaluated only in a focused context.

Once a distraction warning starts, switching between outside-focus websites and unlisted apps does not reset it. The warning stops only after ADHD Guard observes a focused context.

If the browser URL cannot be read, ADHD Guard shows a permission warning and falls back to the application rule. It deliberately avoids a false alarm based only on missing Automation access.

## Current MVP limits

- This is a warning and accountability tool, not a hard blocker. It does not close apps, navigate tabs, or intercept network traffic.
- Browser URL support depends on each browser's AppleScript interface and macOS Automation permission.
- Rules are global. Named focus profiles and schedules are natural next steps.
- The Xcode target enables the hardened runtime and Apple Events entitlement. Distribution still requires selecting an Apple Developer team, Developer ID signing, and notarization.
