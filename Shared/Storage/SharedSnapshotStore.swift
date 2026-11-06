import Foundation
import Security

/// Shares the latest `AppSnapshot` between the app and the widget extension.
///
/// App Groups would need an identifier registered in the developer portal, which the
/// App Store Connect API key used by CI cannot create. A shared keychain access group
/// (`$(AppIdentifierPrefix)<bundle id>.shared`) works with automatic signing alone.
enum SharedSnapshotStore {
    private static let service = "com.leonardoramirezr.24hclock.snapshot"
    private static let account = "snapshot"

    /// Reads the snapshot written by the app, if any.
    static func load() -> AppSnapshot? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }

    /// Replaces the shared snapshot. Returns `false` when the keychain refused it.
    @discardableResult
    static func save(_ snapshot: AppSnapshot) -> Bool {
        guard let data = try? JSONEncoder.snapshot.encode(snapshot) else { return false }
        SecItemDelete(baseQuery as CFDictionary)

        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if let group = accessGroup {
            attributes[kSecAttrAccessGroup as String] = group
            if SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess { return true }
            attributes.removeValue(forKey: kSecAttrAccessGroup as String)
        }
        // Without an explicit group the item goes to the first entry of `keychain-access-groups`.
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    /// The shared access group from Info.plist, when it carries a team prefix.
    private static var accessGroup: String? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "SharedKeychainGroup") as? String,
              !group.contains("$(") else { return nil }
        let prefix = group.split(separator: ".", maxSplits: 1).first ?? ""
        return prefix.count == 10 ? group : nil
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
