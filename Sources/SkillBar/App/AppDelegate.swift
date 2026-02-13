import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var statusItem: NSStatusItem?
    private(set) var popover: NSPopover?
    private(set) var viewModel: SkillListViewModel?
    private var fileWatcher: FileWatcher?
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupViewModel()
        setupStatusItem()
        setupPopover()
        setupFileWatcher()
        registerHotkey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        viewModel?.stopWatching()
        fileWatcher = nil
        unregisterHotkey()
    }

    // MARK: - Setup

    private func setupViewModel() {
        let fileSystem = DefaultFileSystemProvider()
        let scanner = SkillScanner(
            fileSystem: fileSystem,
            scanDirectories: Constants.scanDirectories
        )
        viewModel = SkillListViewModel(scanner: scanner)
    }

    private func setupFileWatcher() {
        guard let viewModel else { return }
        let watcher = FileWatcher(directories: Constants.scanDirectories)
        fileWatcher = watcher
        viewModel.startWatching(watcher)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "terminal", accessibilityDescription: "SkillBar")
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
        let hostingController = NSHostingController(
            rootView: SkillListView(viewModel: viewModel)
        )
        hostingController.sizingOptions = .preferredContentSize
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear
        pop.contentViewController = hostingController
        popover = pop
    }

    // MARK: - Global Hotkey (Carbon)

    private func registerHotkey() {
        let eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        var handlerRef: EventHandlerRef?
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let delegate = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    delegate.togglePopover()
                }
                return noErr
            },
            1,
            [eventSpec],
            selfPtr,
            &handlerRef
        )
        eventHandlerRef = handlerRef

        let hotkeyID = Constants.hotkeyID
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            Constants.carbonHotkeyKeyCode,
            Constants.carbonHotkeyModifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        hotkeyRef = ref
    }

    private func unregisterHotkey() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    // MARK: - Status Item Actions

    @objc func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    @objc func togglePopover() {
        guard let popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit SkillBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem?.menu = menu
        button.performClick(nil)
        // Clear menu so left-click goes back to showing popover
        statusItem?.menu = nil
    }
}
