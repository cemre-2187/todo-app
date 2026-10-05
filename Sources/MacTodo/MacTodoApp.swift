import AppKit
import SwiftUI

@main
struct MacTodoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = Store()

    var body: some Scene {
        WindowGroup("To Do") {
            ContentView()
                .environment(store)
                .environment(\.locale, Locale(identifier: "tr_TR"))
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .commands {
            TextFormattingCommands()
            CommandGroup(after: .newItem) {
                Button("Yeni Liste") { store.addList() }
                    .keyboardShortcut("l", modifiers: [.command, .shift])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // `swift run` ile başlatıldığında da Dock'ta görünsün ve öne gelsin.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
