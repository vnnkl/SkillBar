@testable import SkillBar

final class MockFileSystemProvider: FileSystemProvider, @unchecked Sendable {
    var directories: [String: [String]] = [:]
    var files: [String: String] = [:]
    var symlinks: Set<String> = []
    var existingPaths: Set<String> = []

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        guard let contents = directories[path] else {
            throw MockFileSystemError.directoryNotFound(path)
        }
        return contents
    }

    func fileExists(atPath path: String) -> Bool {
        existingPaths.contains(path) || files[path] != nil
    }

    func contentsOfFile(atPath path: String) throws -> String {
        guard let content = files[path] else {
            throw MockFileSystemError.fileNotFound(path)
        }
        return content
    }

    func isSymlink(atPath path: String) -> Bool {
        symlinks.contains(path)
    }

    func resolvedPath(atPath path: String) -> String {
        path
    }
}

enum MockFileSystemError: Error {
    case directoryNotFound(String)
    case fileNotFound(String)
}
