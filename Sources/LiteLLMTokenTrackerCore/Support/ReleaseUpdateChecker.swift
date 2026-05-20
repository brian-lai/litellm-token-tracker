import Foundation

public protocol ReleaseUpdateChecking: Sendable {
    func checkForUpdate(currentVersion: String) async -> URL?
}

public struct GitHubReleaseUpdateChecker: ReleaseUpdateChecking {
    private let repository: String
    private let loader: URLLoading

    public init(
        repository: String = "brian-lai/litellm_token_tracker",
        loader: URLLoading = URLSessionLoader()
    ) {
        self.repository = repository
        self.loader = loader
    }

    public func checkForUpdate(currentVersion: String) async -> URL? {
        guard
            let metadataURL = URL(string: "https://api.github.com/repos/\(repository)/releases/latest"),
            let current = SemanticVersion.parse(currentVersion)
        else {
            return nil
        }

        var request = URLRequest(url: metadataURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await loader.data(for: request)
        } catch {
            return nil
        }

        guard response.statusCode == 200 else {
            return nil
        }

        let release: ReleasePayload
        do {
            release = try JSONDecoder().decode(ReleasePayload.self, from: data)
        } catch {
            return nil
        }

        guard let latest = SemanticVersion.parse(release.tagName), latest > current else {
            return nil
        }

        return release.htmlURL
    }
}

private struct ReleasePayload: Decodable {
    let tagName: String
    let htmlURL: URL

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}

private struct SemanticVersion: Comparable {
    let components: [Int]

    static func parse(_ rawValue: String) -> SemanticVersion? {
        var trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("v") || trimmed.hasPrefix("V") {
            trimmed.removeFirst()
        }
        let numbers = trimmed.split(separator: ".").compactMap { Int($0) }
        guard !numbers.isEmpty else {
            return nil
        }
        return SemanticVersion(components: numbers)
    }

    static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}
