import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    private(set) var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "SkillBar")
            button.action = #selector(togglePopover)
            button.target = self
        }
        statusItem = item
    }

    private func setupPopover() {
        let pop = NSPopover()
        pop.contentSize = NSSize(width: 400, height: 500)
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(rootView: PlaceholderView())
        popover = pop
    }

    @objc private func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }
}
