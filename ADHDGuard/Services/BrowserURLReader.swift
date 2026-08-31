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
