import AppKit
import Foundation

struct BrowserDescriptor {
    let bundleIdentifier: String
    let applicationName: String
    let urlScript: String
}

enum BrowserURLReader {
    static let browsers: [BrowserDescriptor] = [
        BrowserDescriptor(
            bundleIdentifier: "com.apple.Safari",
            applicationName: "Safari",
            urlScript: "tell application \"Safari\" to return URL of current tab of front window"
        ),
        BrowserDescriptor(
            bundleIdentifier: "com.google.Chrome",
            applicationName: "Google Chrome",
            urlScript: "tell application \"Google Chrome\" to return URL of active tab of front window"
        ),
        BrowserDescriptor(
            bundleIdentifier: "com.microsoft.edgemac",
            applicationName: "Microsoft Edge",
            urlScript: "tell application \"Microsoft Edge\" to return URL of active tab of front window"
        ),
        BrowserDescriptor(
            bundleIdentifier: "com.brave.Browser",
            applicationName: "Brave Browser",
            urlScript: "tell application \"Brave Browser\" to return URL of active tab of front window"
        ),
        BrowserDescriptor(
            bundleIdentifier: "company.thebrowser.Browser",
            applicationName: "Arc",
            urlScript: "tell application \"Arc\" to return URL of active tab of front window"
        )
    ]

    static func descriptor(for bundleIdentifier: String) -> BrowserDescriptor? {
        browsers.first { $0.bundleIdentifier.caseInsensitiveCompare(bundleIdentifier) == .orderedSame }
    }

    static func currentURL(for descriptor: BrowserDescriptor) -> Result<URL, BrowserReadError> {
        guard let script = NSAppleScript(source: descriptor.urlScript) else {
            return .failure(.invalidScript)
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Automation access was denied."
            return .failure(.automation(message))
        }

        guard let value = result.stringValue, let url = URL(string: value) else {
            return .failure(.missingTab)
        }
        return .success(url)
    }

    static func activateExistingTab(url: URL, for descriptor: BrowserDescriptor) -> Bool {
        guard let source = tabActivationScript(for: descriptor, url: url),
              let script = NSAppleScript(source: source) else {
            return false
        }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        return error == nil && result.booleanValue
    }

    static func tabActivationScript(for descriptor: BrowserDescriptor, url: URL) -> String? {
        let targetURL = escapedAppleScriptString(url.absoluteString)

        if descriptor.bundleIdentifier == "com.apple.Safari" {
            return """
            set targetURL to "\(targetURL)"
            tell application "Safari"
                repeat with windowIndex from 1 to count of windows
                    set candidateWindow to window windowIndex
                    repeat with tabIndex from 1 to count of tabs of candidateWindow
                        set candidateTab to tab tabIndex of candidateWindow
                        if URL of candidateTab is targetURL then
                            set current tab of candidateWindow to candidateTab
                            set index of candidateWindow to 1
                            activate
                            return true
                        end if
                    end repeat
                end repeat
            end tell
            return false
            """
        }

        let chromiumBundleIdentifiers = [
            "com.google.Chrome",
            "com.microsoft.edgemac",
            "com.brave.Browser",
            "company.thebrowser.Browser"
        ]
        guard chromiumBundleIdentifiers.contains(descriptor.bundleIdentifier) else { return nil }

        return """
        set targetURL to "\(targetURL)"
        tell application "\(descriptor.applicationName)"
            repeat with windowIndex from 1 to count of windows
                set candidateWindow to window windowIndex
                repeat with tabIndex from 1 to count of tabs of candidateWindow
                    if URL of tab tabIndex of candidateWindow is targetURL then
                        set active tab index of candidateWindow to tabIndex
                        set index of candidateWindow to 1
                        activate
                        return true
                    end if
                end repeat
            end repeat
        end tell
        return false
        """
    }

    private static func escapedAppleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

enum BrowserReadError: LocalizedError, Equatable {
    case invalidScript
    case automation(String)
    case missingTab

    var errorDescription: String? {
        switch self {
        case .invalidScript:
            "Could not create the browser automation script."
        case let .automation(message):
            "Browser access failed: \(message)"
        case .missingTab:
            "The browser has no readable active tab."
        }
    }
}
