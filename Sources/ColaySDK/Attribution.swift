import Foundation

/// Extracts ad attribution data (UTM parameters, click IDs) from links.
enum Attribution {

    static let keys: [String] = [
        "utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "utm_id",
        "fbclid", "gclid", "gbraid", "wbraid", "ttclid", "ctwa_clid", "msclkid", "colay_link",
    ]

    /// Click IDs that can identify a person; not sent without ads consent.
    static let clickIds: Set<String> = ["fbclid", "gclid", "gbraid", "wbraid", "ttclid", "ctwa_clid", "msclkid"]

    static func fromURL(_ url: URL) -> [String: String] {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
        var out: [String: String] = [:]
        for item in items where keys.contains(item.name) {
            if let v = item.value, !v.isEmpty, out[item.name] == nil { out[item.name] = v }
        }
        return out
    }

    static func stripClickIds(_ attr: [String: Any]) -> [String: Any] {
        attr.filter { !clickIds.contains($0.key) }
    }
}
