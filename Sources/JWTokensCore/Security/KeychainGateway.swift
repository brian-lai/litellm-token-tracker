import Foundation
import Security

public protocol KeychainGateway: Sendable {
    func read(service: String, account: String) throws -> String?
    func save(_ value: String, service: String, account: String) throws
    func delete(service: String, account: String) throws
}

public struct SecItemKeychainGateway: KeychainGateway {
    public init() {}

    public func read(service: String, account: String) throws -> String? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw APIKeyStoreError.unavailable
        }
        guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else {
            throw APIKeyStoreError.unavailable
        }
        return value
    }

    public func save(_ value: String, service: String, account: String) throws {
        let data = Data(value.utf8)
        if try read(service: service, account: account) == nil {
            var query = baseQuery(service: service, account: account)
            query[kSecValueData as String] = data
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw APIKeyStoreError.unavailable
            }
        } else {
            let query = baseQuery(service: service, account: account)
            let attributes = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard status == errSecSuccess else {
                throw APIKeyStoreError.unavailable
            }
        }
    }

    public func delete(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw APIKeyStoreError.unavailable
        }
    }

    private func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
