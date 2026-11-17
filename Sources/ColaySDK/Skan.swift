import Foundation

/// One rule of the SKAdNetwork conversion value schema defined on the ColayAI dashboard
/// ("Tracking setup" → iOS source). When `event` is tracked (with revenue ≥ `minRevenue`, if set),
/// the conversion value becomes at least `fine`.
struct SkanRule: Equatable {
    let event: String
    let fine: Int
    let coarse: ColayCoarseValue
    let minRevenue: Double?

    init(event: String, fine: Int, coarse: ColayCoarseValue = .low, minRevenue: Double? = nil) {
        self.event = event
        self.fine = max(0, min(63, fine))
        self.coarse = coarse
        self.minRevenue = minRevenue
    }

    init?(json: [String: Any]) {
        guard let event = json["event"] as? String, !event.isEmpty,
              let fine = (json["fine"] as? NSNumber)?.intValue else { return nil }
        let coarse: ColayCoarseValue
        switch (json["coarse"] as? String)?.lowercased() {
        case "high": coarse = .high
        case "medium": coarse = .medium
        default: coarse = .low
        }
        self.init(event: event, fine: fine, coarse: coarse, minRevenue: (json["minRevenue"] as? NSNumber)?.doubleValue)
    }
}

enum Skan {
    /// SKAdNetwork 4 measurement windows: days 0-2, 3-7 and 8-35 after install.
    static func window(installedAt: TimeInterval, now: TimeInterval) -> Int? {
        let days = (now - installedAt) / 86_400
        if days < 0 { return 0 }
        if days < 2 { return 0 }
        if days < 7 { return 1 }
        if days < 35 { return 2 }
        return nil
    }

    /// The rule to apply for an event, or nil if the value would not go up.
    /// Picks the highest matching value; the value never decreases within a window.
    static func target(rules: [SkanRule], event: String, revenue: Double?, current: Int) -> SkanRule? {
        rules
            .filter { $0.event == event && $0.fine > current }
            .filter { r in
                guard let min = r.minRevenue, min > 0 else { return true }
                return (revenue ?? 0) >= min
            }
            .max { $0.fine < $1.fine }
    }

    static func parse(_ data: Data) -> [SkanRule]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skan = root["skan"] as? [String: Any],
              let rules = skan["rules"] as? [[String: Any]] else { return nil }
        return rules.compactMap(SkanRule.init(json:))
    }
}
