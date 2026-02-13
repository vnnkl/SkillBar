import AppKit

// MARK: - FileSystemProvider

protocol FileSystemProvider: Sendable {
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func fileExists(atPath path: String) -> Bool
    func contentsOfFile(atPath path: String) throws -> String
    func isSymlink(atPath path: String) -> Bool
    func resolvedPath(atPath path: String) -> String
}

// MARK: - SkillScanning

protocol SkillScanning: Sendable {
    func scan() throws -> [Skill]
}

// MARK: - FileWatching

protocol FileWatching: Sendable {
    func start(onChange: @escaping @Sendable () -> Void)
    func stop()
}

// MARK: - ClipboardProvider

protocol ClipboardProvider: Sendable {
    func copy(_ string: String)
}

// MARK: - KeyValueStore

protocol KeyValueStore: Sendable {
    func array(forKey key: String) -> [String]?
    func set(_ value: [String], forKey key: String)
    func removeObject(forKey key: String)
}

// MARK: - PopoverControlling

@MainActor
protocol PopoverControlling {
    var isShown: Bool { get }
    func toggle()
}
