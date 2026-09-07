# App Sandbox

App Sandbox is enabled for both Debug and Release. Keep it enabled when developing
features so local testing exercises the same access restrictions as the store build.

## Capabilities

- `app-sandbox`: isolates the app and its local settings.
- `automation.apple-events`: permits Apple Events under Hardened Runtime.
- `temporary-exception.apple-events`: permits scripting only Safari, Chrome, Edge,
  Brave, and Arc, matching `BrowserURLReader.browsers`. The app reads the active tab
  URL. A user-initiated return searches open tab URLs and selects a matching tab.
  macOS Automation consent is still required independently of these entitlements.
- `files.user-selected.read-only`: reads an app bundle selected with `NSOpenPanel`
  to obtain its name and bundle identifier. No persistent file access is needed.

No network, microphone, screen recording, Accessibility, or full-disk capability
is added. Apple Events exceptions must be justified during Mac App Store review;
working locally does not establish App Review approval.

## Existing settings

`Resources/container-migration.plist` asks macOS to migrate the app's existing
preferences when its sandbox container is first created. This includes rules,
recent activity, reminder positions, and the launch-at-login prompt choice.
The manifest does not rerun for an existing container. Preserve user settings
before any first-launch migration experiment.

## Verification on 2026-09-07

- Debug build passed; 44 existing XCTest tests passed with the sandboxed test host.
- Release build signed with an Apple Development certificate passed signature
  verification, with App Sandbox and Hardened Runtime enabled.
- Safari and Chrome: active test URL detection and return to an existing tab passed.
- A temporary distracting-site rule triggered the alarm after the configured
  10-second delay. macOS reported both 560 × 132 reminder panels as on-screen;
  returning to an allowed site cleared the alarm state.
- Selecting Safari through `NSOpenPanel` successfully read its bundle metadata.
- A sandboxed probe compiling the app's unchanged `IdleTimeProvider` reported a
  container home, an available active app/session, and finite increasing idle times.
- A separate test bundle migrated a synthetic configuration (13-second delay and
  one sentinel focus app) into its new container.
- The existing user's configuration was restored to its original values after
  testing and compared equal to its backup. Settings and recent activity survived
  the final app restart; no temporary website rule or enabled focus session remains.

Edge, Brave, and Arc were not installed and were not tested at runtime. Login-item
registration and a full lock/unlock cycle were not exercised in this check.

Ad-hoc Xcode signing disables Hardened Runtime, so use a development certificate
for the final local Release check. XCTest needs access to the system test manager;
a restriction imposed by the development agent's own execution environment is
separate from the app's App Sandbox.

## Apple references

- [Apple Events sandbox exceptions](https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/EntitlementKeyReference/Chapters/AppSandboxTemporaryExceptionEntitlements.html)
- [Container migration](https://developer.apple.com/documentation/security/migrating-your-app-s-files-to-its-app-sandbox-container)
- [Exception explanations for App Review](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information)
