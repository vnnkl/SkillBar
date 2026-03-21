import Foundation
@testable import SkillBar

final class InMemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    var storage: [String: [String]] = [:]
    var dataStorage: [String: Data] = [:]

    func array(forKey key: String) -> [String]? {
        storage[key]
    }

    func set(_ value: [String], forKey key: String) {
        storage[key] = value
    }

    func data(forKey key: String) -> Data? {
        dataStorage[key]
    }

    func set(_ value: Data, forKey key: String) {
        dataStorage[key] = value
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
        dataStorage.removeValue(forKey: key)
    }
}
