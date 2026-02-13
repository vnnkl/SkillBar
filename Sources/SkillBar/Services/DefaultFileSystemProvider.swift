import Foundation

final class DefaultFileSystemProvider: FileSystemProvider, @unchecked Sendable {
    private let manager = FileManager.default

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        try manager.contentsOfDirectory(atPath: path)
    }

    func fileExists(atPath path: String) -> Bool {
        manager.fileExists(atPath: path)
    }

    func contentsOfFile(atPath path: String) throws -> String {
        guard let data = manager.contents(atPath: path),
              let content = String(data: data, encoding: .utf8) else {
            throw FileSystemError.unreadable(path)
        }
        return content
    }

    func isSymlink(atPath path: String) -> Bool {
        let attributes = try? manager.attributesOfItem(atPath: path)
        return attributes?[.type] as? FileAttributeType == .typeSymbolicLink
    }

    func resolvedPath(atPath path: String) -> String {
        (try? manager.destinationOfSymbolicLink(atPath: path)) ?? path
    }
}

enum FileSystemError: Error {
    case unreadable(String)
}
