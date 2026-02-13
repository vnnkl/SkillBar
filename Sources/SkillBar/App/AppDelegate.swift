import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    private(set) var popover: NSPopover?
    private(set) var viewModel: SkillListViewModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupViewModel()
        setupStatusItem()
        setupPopover()
    }

    private func setupViewModel() {
        let fileSystem = DefaultFileSystemProvider()
        let scanner = SkillScanner(
            fileSystem: fileSystem,
            scanDirectories: Constants.scanDirectories
        )
        viewModel = SkillListViewModel(scanner: scanner)
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
        guard let viewModel else { return }
        let pop = NSPopover()
        pop.contentSize = NSSize(
            width: Constants.popoverWidth,
            height: Constants.popoverHeight
        )
        pop.behavior = .transient
        pop.contentViewController = NSHostingController(
            rootView: SkillListView(viewModel: viewModel)
        )
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
