import SwiftUI
import AppKit

@main
struct HeylloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
