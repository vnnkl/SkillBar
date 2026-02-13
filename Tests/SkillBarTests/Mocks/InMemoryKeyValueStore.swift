@testable import SkillBar

final class InMemoryKeyValueStore: KeyValueStore, @unchecked Sendable {
    var storage: [String: [String]] = [:]

    func array(forKey key: String) -> [String]? {
        storage[key]
    }

    func set(_ value: [String], forKey key: String) {
        storage[key] = value
    }

    func removeObject(forKey key: String) {
        storage.removeValue(forKey: key)
    }
}
