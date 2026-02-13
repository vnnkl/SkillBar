import Testing
import Foundation
@testable import SkillBar

@Suite("FileWatcher Integration Tests")
struct FileWatcherIntegrationTests {

    // MARK: - Helpers

    private func makeTempDirectory() throws -> String {
        let dir = NSTemporaryDirectory() + "SkillBarTest-\(UUID().uuidString)"
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir
    }

    private func removeTempDirectory(_ path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }

    // MARK: - Start / Stop

    @Test("Start increments internal state, stop cleans up")
    func startAndStop() throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {})
        watcher.stop()
    }

    @Test("Multiple stops do not crash")
    func multipleStopsAreSafe() throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {})
        watcher.stop()
        watcher.stop()
    }

    // MARK: - File Change Detection

    @Test("Detects new file creation")
    func detectsNewFile() async throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let expectation = Expectation()
        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {
            expectation.fulfill()
        })
        defer { watcher.stop() }

        // Small delay to let FSEventStream initialize
        try await Task.sleep(for: .milliseconds(200))

        let filePath = "\(dir)/SKILL.md"
        try "test content".write(toFile: filePath, atomically: true, encoding: .utf8)

        await expectation.waitWithTimeout(seconds: 3)
        #expect(expectation.isFulfilled)
    }

    @Test("Detects file modification")
    func detectsFileModification() async throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let filePath = "\(dir)/SKILL.md"
        try "original".write(toFile: filePath, atomically: true, encoding: .utf8)

        let expectation = Expectation()
        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {
            expectation.fulfill()
        })
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(200))

        try "modified".write(toFile: filePath, atomically: true, encoding: .utf8)

        await expectation.waitWithTimeout(seconds: 3)
        #expect(expectation.isFulfilled)
    }

    @Test("Detects file deletion")
    func detectsFileDeletion() async throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let filePath = "\(dir)/SKILL.md"
        try "content".write(toFile: filePath, atomically: true, encoding: .utf8)

        let expectation = Expectation()
        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {
            expectation.fulfill()
        })
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(200))

        try FileManager.default.removeItem(atPath: filePath)

        await expectation.waitWithTimeout(seconds: 3)
        #expect(expectation.isFulfilled)
    }

    @Test("Detects changes in subdirectories (recursive)")
    func detectsSubdirectoryChanges() async throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let subdir = "\(dir)/subskill"
        try FileManager.default.createDirectory(atPath: subdir, withIntermediateDirectories: true)

        let expectation = Expectation()
        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {
            expectation.fulfill()
        })
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(200))

        try "nested content".write(toFile: "\(subdir)/SKILL.md", atomically: true, encoding: .utf8)

        await expectation.waitWithTimeout(seconds: 3)
        #expect(expectation.isFulfilled)
    }

    // MARK: - Debounce

    @Test("Rapid changes are debounced into single callback")
    func debouncesRapidChanges() async throws {
        let dir = try makeTempDirectory()
        defer { removeTempDirectory(dir) }

        let counter = Counter()
        let watcher = FileWatcher(directories: [dir])
        watcher.start(onChange: {
            counter.increment()
        })
        defer { watcher.stop() }

        try await Task.sleep(for: .milliseconds(200))

        // Write 5 files rapidly
        for i in 0..<5 {
            try "content \(i)".write(toFile: "\(dir)/file\(i).md", atomically: true, encoding: .utf8)
        }

        // Wait for debounce to settle (debounce is 0.5s + some margin)
        try await Task.sleep(for: .seconds(1.5))

        // Should have fewer callbacks than file writes
        #expect(counter.value < 5, "Expected debounce to reduce \(counter.value) callbacks to fewer than 5")
    }
}

// MARK: - Test Helpers

private final class Expectation: @unchecked Sendable {
    private let lock = NSLock()
    private var _fulfilled = false

    var isFulfilled: Bool {
        lock.withLock { _fulfilled }
    }

    func fulfill() {
        lock.withLock { _fulfilled = true }
    }

    func waitWithTimeout(seconds: TimeInterval) async {
        let deadline = Date().addingTimeInterval(seconds)
        while !isFulfilled && Date() < deadline {
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}

private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0

    var value: Int {
        lock.withLock { _value }
    }

    func increment() {
        lock.withLock { _value += 1 }
    }
}
