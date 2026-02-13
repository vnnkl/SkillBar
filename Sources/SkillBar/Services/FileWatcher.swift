import Foundation

final class FileWatcher: FileWatching, @unchecked Sendable {
    private let directories: [String]
    private let debounceInterval: TimeInterval
    private var stream: FSEventStreamRef?
    private var debounceWorkItem: DispatchWorkItem?
    private var onChange: (@Sendable () -> Void)?
    private let queue = DispatchQueue(label: "com.skillbar.filewatcher")

    init(
        directories: [String],
        debounceInterval: TimeInterval = Constants.debounceInterval
    ) {
        self.directories = directories
        self.debounceInterval = debounceInterval
    }

    deinit {
        stop()
    }

    func start(onChange: @escaping @Sendable () -> Void) {
        stop()
        self.onChange = onChange

        let paths = directories as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.handleEvent()
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            debounceInterval,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents)
        ) else { return }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    func stop() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
        onChange = nil

        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            self.stream = nil
        }
    }

    // MARK: - Private

    private func handleEvent() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: work)
    }
}
