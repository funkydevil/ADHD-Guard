# ADHD Guard — English App Store copy

Prepared 2026-09-07 from the current source and supplied screenshots. The English listing was saved through CLI and verified against App Store Connect on 2026-09-07. All four Mac screenshots are COMPLETE at 2560 × 1600. See ../app-store-connect-receipt.json for verification. The version remains Prepare for Submission; no review submission was made. The support and privacy pages are published separately on GitHub Pages.

## Customer-facing fields

| Field | Value / file | Length |
| --- | --- | --- |
| Name | ADHD Guard | 10 / 30 characters |
| Subtitle | Focus reminders for your Mac | 28 / 30 characters |
| Promotional Text | promotional-text.txt | 146 / 170 characters |
| Description | description.txt | 1894 / 4000 characters |
| Keywords | keywords.txt | 97 / 100 bytes; ASCII |
| Primary category | Productivity | Matches the current app category |

Keep the app name as ADHD Guard. The subtitle explains the product and platform without changing the established name. The keyword list avoids repeating the app name and subtitle terms; it is an editorial selection, not a search-volume or ranking claim.

Use promotional text if the field is available for the target platform/localization.

For the initial app version, What's New is not available; no invented update notes are included. Write it against actual changes for later releases.

## App Review

- Sign-in required: No.
- Notes: review-notes.txt.
- App Sandbox Information: app-sandbox-usage-information.txt, saved and verified for com.apple.security.temporary-exception.apple-events (978 / 1000 characters).
- Extended App Sandbox explanation: sandbox-justification.txt, also included in App Review Notes.
- Review contact email: kp.gentle.support@gmail.com. Other contact fields are maintained in App Store Connect.

The reminder scenario deliberately sets a 10-second buffer: the current default in source is 20 seconds, while the screenshots show a user's 10-second setting.

Browser detection and return are implemented for Safari, Chrome, Edge, Brave and Arc. The repository's sandbox verification documents runtime checks only for Safari and Chrome. Customer-facing copy names those two browsers; the entitlement explanation accurately lists all five targets.

## Published pages and contact

- Support URL: https://funkydevil.github.io/adhd-guard/support.html
- Privacy Policy URL: https://funkydevil.github.io/adhd-guard/privacy.html
- Support email: kp.gentle.support@gmail.com.
- GitHub Issues: https://github.com/funkydevil/funkydevil.github.io/issues. Include ADHD Guard in the issue title.
- Website repository: funkydevil/funkydevil.github.io; the app source repository remains private.
- English source copy: support-page.md and privacy-policy.md.
- Marketing URL: https://funkydevil.github.io/adhd-guard/. English landing page published on GitHub Pages and saved in App Store Connect.
- Copyright field: 2026 Kirill Piulziu, matching the verified developer account name.

The page files contain no unresolved placeholders. The privacy policy explains public GitHub Issues and GitHub Pages hosting separately from local app data.

Before submission, attach the appropriate build, provide the private App Review contact details, and complete the remaining release declarations. The Data Not Collected declaration was explicitly created and published; the published state was verified. Content Rights is saved as DOES_NOT_USE_THIRD_PARTY_CONTENT. Pricing awaits the user decision.

## App privacy working assessment

The reviewed app source uses local storage and has no activity-upload implementation or third-party analytics SDK. Under Apple's definition, information processed only on the device is not collected for the App Privacy label. This supports a Data Not Collected answer for the reviewed app, subject to the actual submitted build and any developer-accessible data from integrations or support flows.

Local storage does include full recent URLs, not only domains. Recent activity also updates while Focus mode is off. The privacy draft and support copy describe both details explicitly.

## Reference limits and requirements

- [App information: name, subtitle, privacy URL](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
- [Version information: description, keywords, promotional text, review notes and first-version release notes](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information)
- [App Sandbox explanations](https://developer.apple.com/help/app-store-connect/reference/app-uploads/app-sandbox-information)
- [App Privacy definitions](https://developer.apple.com/app-store/app-privacy-details/)

## Local evidence

- ADHDGuard/Models/GuardConfiguration.swift: app rules, browser targets, defaults.
- ADHDGuard/Services/GuardMonitor.swift: buffer behavior, focus return and paused reminders.
- ADHDGuard/Services/GuardSessionState.swift: recent activity and persisted URLs.
- ADHDGuard/Services/ConfigurationStore.swift: local settings.
- ADHDGuard/Services/BrowserURLReader.swift: active tab checks and open-tab search.
- ADHDGuard/Services/IdleTimeProvider.swift: elapsed time since input events.
- ADHDGuard/Views/PreferencesView.swift: custom phrases, preview, timing and login settings.
- Resources/ADHDGuard.entitlements: sandbox capabilities.
- docs/SANDBOX.md: scope of prior browser runtime verification.

