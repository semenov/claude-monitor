import Foundation

struct Usage: Codable, Equatable {
    struct Limit: Codable, Equatable, Identifiable {
        let id: String
        let label: String
        let percent: Double
        let resetsAt: Date?
        let resets: String
    }

    let plan: String
    let limits: [Limit]
    let insights: [String]
    let fetchedAt: Date

    /// The 5-hour session limit, shown as the main gauge.
    var session: Limit? { limits.first { $0.id.contains("session") } ?? limits.first }
    /// The weekly limit across all models.
    var week: Limit? { limits.first { $0.id.contains("week") && $0.id.contains("all") } ?? limits.first { $0.id.contains("week") } }
}

/// Settings, cache and networking shared by the app and the widget through an App Group.
enum UsageAPI {
    static let appGroup = "group.ai.semenov.claude-monitor"
    static var defaults: UserDefaults { UserDefaults(suiteName: appGroup) ?? .standard }
    private static let cacheKey = "lastUsage"

    static var publicURL: String {
        get { defaults.string(forKey: "publicURL") ?? Secrets.publicServer }
        set { defaults.set(newValue, forKey: "publicURL") }
    }
    static var token: String {
        get { defaults.string(forKey: "token") ?? Secrets.homebaseToken }
        set { defaults.set(newValue, forKey: "token") }
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    static var cached: Usage? {
        defaults.data(forKey: cacheKey).flatMap { try? decoder.decode(Usage.self, from: $0) }
    }

    static func fetch(force: Bool = false, timeout: TimeInterval = 75) async throws -> Usage {
        let base = publicURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: base + "/api/usage" + (force ? "?refresh=1" : "")) else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if !token.isEmpty {
            req.setValue(token, forHTTPHeaderField: "X-Homebase-Token")
        }
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: msg ?? "HTTP \(http.statusCode)"])
        }
        let usage = try decoder.decode(Usage.self, from: data)
        defaults.set(data, forKey: cacheKey)
        return usage
    }
}
