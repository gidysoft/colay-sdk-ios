import Foundation
#if canImport(UIKit)
import UIKit
#endif

let ColaySDKVersion = "0.1.2"

/// SDK core. All state changes happen on a single serial queue (`work`);
/// public API calls only hand work to that queue and never block the app.
final class Client {
    private let key: String
    private let config: ColayConfig
    private let work = DispatchQueue(label: "com.colayai.sdk")
    private let defaults: UserDefaults
    private let transport: Transport
    private var timer: DispatchSourceTimer?

    // accessed on the `work` queue only
    private var queue: EventQueue!
    private var anonymousId = ""
    private var userId: String?
    private var consent: ColayConsent
    private var sessionId: String?
    private var lastEventAt: TimeInterval = 0
    private var pendingAttribution: [String: Any] = [:]
    private var contextBase: [String: Any]?
    private var backoff: TimeInterval = 0
    private var backoffUntil: TimeInterval = 0
    private var disabled = false
    private var foregroundSince: TimeInterval = 0

    private(set) var currentAnonymousId = ""

    init(key: String, config: ColayConfig, defaults: UserDefaults = UserDefaults(suiteName: "com.colayai.sdk") ?? .standard) {
        self.key = key
        self.config = config
        self.defaults = defaults
        self.transport = Transport(baseURL: config.baseURL, key: key)
        self.consent = config.defaultConsent

        work.async { self.setUp() }
        startTimer()
        observeLifecycle()
    }

    // MARK: public operations

    func track(_ name: String, _ properties: [String: Any], revenue: Double? = nil, currency: String? = nil) {
        work.async { self.enqueue(type: "track", name: name, properties: properties, revenue: revenue, currency: currency) }
    }

    func screen(_ name: String, _ properties: [String: Any]) {
        work.async { self.enqueue(type: "screen", name: name, properties: properties) }
    }

    func identify(_ id: String, _ traits: [String: Any]) {
        work.async {
            self.userId = id
            self.defaults.set(id, forKey: K.user)
            self.enqueue(type: "identify", name: "identify", properties: [:], traits: traits)
        }
    }

    func reset() {
        work.async {
            self.flushNow()
            self.userId = nil
            self.anonymousId = UUID().uuidString
            self.currentAnonymousId = self.anonymousId
            self.sessionId = nil
            self.lastEventAt = 0
            self.defaults.removeObject(forKey: K.user)
            self.defaults.removeObject(forKey: K.session)
            self.defaults.removeObject(forKey: K.last)
            self.defaults.set(self.anonymousId, forKey: K.anon)
        }
    }

    func setConsent(_ c: ColayConsent) {
        work.async {
            self.consent = c
            self.defaults.set(c.analytics, forKey: K.consentA)
            self.defaults.set(c.ads, forKey: K.consentAds)
            if !c.analytics { self.queue.clear() }
            self.log("consent: \(c)")
        }
    }

    func handleDeepLink(_ url: URL) {
        work.async {
            let attr = Attribution.fromURL(url)
            var full: [String: Any] = attr
            full["deeplink"] = url.absoluteString
            if !attr.isEmpty { self.pendingAttribution = full }
            self.enqueue(type: "track", name: "deeplink_open", properties: ["url": url.absoluteString], attribution: full)
        }
    }

    func flush(completion: (() -> Void)? = nil) {
        work.async {
            self.flushNow()
            completion?()
        }
    }

    // MARK: internals

    private func setUp() {
        let dir = (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("ColaySDK", isDirectory: true)
        queue = EventQueue(fileURL: dir.appendingPathComponent("queue.jsonl"), maxSize: config.maxQueueSize)
        if let a = defaults.string(forKey: K.anon) {
            anonymousId = a
        } else {
            anonymousId = UUID().uuidString
            defaults.set(anonymousId, forKey: K.anon)
        }
        currentAnonymousId = anonymousId
        userId = defaults.string(forKey: K.user)
        if defaults.object(forKey: K.consentA) != nil {
            consent = ColayConsent(analytics: defaults.bool(forKey: K.consentA), ads: defaults.bool(forKey: K.consentAds))
        }
        sessionId = defaults.string(forKey: K.session)
        lastEventAt = defaults.double(forKey: K.last)
        log("ready: anonymousId=\(anonymousId), consent=\(consent), queue=\(queue.count)")

        if config.trackLifecycle && !defaults.bool(forKey: K.install) {
            var attr: [String: Any] = [:]
            if config.collectAppleSearchAdsToken, let token = PlatformInfo.appleSearchAdsToken() {
                attr["asaToken"] = token
            }
            enqueue(type: "track", name: "app_install", properties: [:], attribution: attr)
            defaults.set(true, forKey: K.install)
            flushNow()
        }
    }

    private func enqueue(type: String, name: String, properties: [String: Any], traits: [String: Any]? = nil,
                         revenue: Double? = nil, currency: String? = nil, attribution: [String: Any]? = nil) {
        guard consent.analytics, !disabled, queue != nil else { return }
        let now = Date().timeIntervalSince1970
        touchSession(now)
        queue.add(buildEvent(type: type, name: name, properties: properties, traits: traits,
                             revenue: revenue, currency: currency, attribution: attribution, at: now))
        log("event: \(type) \(name) (queue \(queue.count))")
        if queue.count >= config.flushAt { flushNow() }
    }

    private func touchSession(_ now: TimeInterval) {
        if sessionId == nil || now - lastEventAt > config.sessionTimeout {
            sessionId = UUID().uuidString
            if config.trackLifecycle {
                let attr = pendingAttribution
                pendingAttribution = [:]
                queue.add(buildEvent(type: "track", name: "session_start", properties: [:], traits: nil, revenue: nil,
                                     currency: nil, attribution: attr.isEmpty ? nil : attr, at: now))
            }
        }
        lastEventAt = now
        defaults.set(sessionId, forKey: K.session)
        defaults.set(now, forKey: K.last)
    }

    private func buildEvent(type: String, name: String, properties: [String: Any], traits: [String: Any]?,
                            revenue: Double?, currency: String?, attribution: [String: Any]?, at: TimeInterval) -> [String: Any] {
        var e: [String: Any] = [
            "id": UUID().uuidString.lowercased(),
            "type": type,
            "name": String(name.prefix(64)),
            "timestamp": JSON.iso(at),
            "anonymousId": anonymousId,
            "sessionId": sessionId ?? "",
            "properties": JSON.limit(properties),
            "consent": ["analytics": consent.analytics, "ads": consent.ads],
        ]
        if let userId { e["userId"] = userId }
        if let traits { e["traits"] = JSON.limit(traits) }
        if let revenue { e["revenue"] = revenue }
        if let currency { e["currency"] = currency.uppercased() }
        if var a = attribution, !a.isEmpty {
            if !consent.ads {
                a = Attribution.stripClickIds(a)
                a.removeValue(forKey: "asaToken")
            }
            if !a.isEmpty { e["attribution"] = JSON.sanitize(a) }
        }
        return e
    }

    private func context() -> [String: Any] {
        if contextBase == nil {
            contextBase = ["app": PlatformInfo.app(), "device": PlatformInfo.device()]
        }
        var c = contextBase!
        if config.collectAdvertisingId && consent.ads, let idfa = PlatformInfo.advertisingId() {
            c["advertisingId"] = idfa
            c["limitAdTracking"] = false
        }
        return c
    }

    private func flushNow() {
        guard queue != nil, !disabled, consent.analytics else { return }
        guard Date().timeIntervalSince1970 >= backoffUntil else { return }
        while queue.count > 0 {
            let batch = queue.peek(Self.maxBatch, maxBytes: Self.maxBytes)
            if batch.isEmpty || !send(batch) { return }
        }
    }

    /// true: keep going; false: stop for now.
    private func send(_ batch: [[String: Any]]) -> Bool {
        let payload: [String: Any] = [
            "sentAt": JSON.iso(Date().timeIntervalSince1970),
            "sdk": ["name": "colay-ios", "version": ColaySDKVersion],
            "context": context(),
            "events": batch,
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            queue.remove(batch)
            return true
        }
        switch transport.send(body) {
        case .ok:
            queue.remove(batch); backoff = 0; log("sent: \(batch.count)"); return true
        case .drop:
            queue.remove(batch); log("batch rejected by the server, dropped: \(batch.count)"); return true
        case .unauthorized:
            queue.clear(); disabled = true
            print("[ColaySDK] Key is invalid or disabled; sending stopped")
            return false
        case .tooLarge:
            if batch.count == 1 { queue.remove(batch); return true }
            return send(Array(batch.prefix(batch.count / 2)))
        case .retry(let after):
            backoff = after ?? (backoff == 0 ? 5 : min(backoff * 2, 600))
            backoffUntil = Date().timeIntervalSince1970 + backoff
            log("send failed, retrying in \(Int(backoff)) s")
            return false
        }
    }

    private func startTimer() {
        let t = DispatchSource.makeTimerSource(queue: work)
        t.schedule(deadline: .now() + config.flushInterval, repeating: config.flushInterval)
        t.setEventHandler { [weak self] in self?.flushNow() }
        t.resume()
        timer = t
    }

    private func observeLifecycle() {
        #if canImport(UIKit) && os(iOS)
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.work.async {
                self.foregroundSince = Date().timeIntervalSince1970
                if self.config.trackLifecycle { self.enqueue(type: "track", name: "app_open", properties: [:]) }
            }
        }
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            // Ask for a few seconds of background time to send
            var task: UIBackgroundTaskIdentifier = .invalid
            task = UIApplication.shared.beginBackgroundTask(withName: "ColaySDK.flush") {
                UIApplication.shared.endBackgroundTask(task)
                task = .invalid
            }
            self.work.async {
                if self.config.trackLifecycle {
                    let secs = Int(Date().timeIntervalSince1970 - self.foregroundSince)
                    self.enqueue(type: "track", name: "app_background", properties: ["duration": secs])
                }
                self.flushNow()
                DispatchQueue.main.async {
                    if task != .invalid { UIApplication.shared.endBackgroundTask(task); task = .invalid }
                }
            }
        }
        #endif
    }

    private func log(_ msg: String) {
        if config.debug { print("[ColaySDK] \(msg)") }
    }

    private static let maxBatch = 100
    private static let maxBytes = 450_000

    private enum K {
        static let anon = "anonymous_id"
        static let user = "user_id"
        static let session = "session_id"
        static let last = "last_event_at"
        static let install = "install_sent"
        static let consentA = "consent_analytics"
        static let consentAds = "consent_ads"
    }
}

enum JSON {
    private static let formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    static func iso(_ t: TimeInterval) -> String { formatter.string(from: Date(timeIntervalSince1970: t)) }

    /// Converts values JSON cannot encode (Date, URL, custom types) to strings.
    static func sanitize(_ value: Any) -> Any {
        switch value {
        case let v as String: return v
        case let v as Bool: return v
        case let v as Int: return v
        case let v as Double: return v.isFinite ? v : 0
        case let v as Float: return Double(v).isFinite ? Double(v) : 0
        case let v as NSNumber: return v
        case let v as Date: return formatter.string(from: v)
        case let v as URL: return v.absoluteString
        case let v as [String: Any]: return v.mapValues { sanitize($0) }
        case let v as [Any]: return v.map { sanitize($0) }
        case is NSNull: return NSNull()
        default: return String(describing: value)
        }
    }

    /// Protocol limits: at most 64 keys, strings up to 1000 characters.
    static func limit(_ dict: [String: Any]) -> [String: Any] {
        var out: [String: Any] = [:]
        for (k, v) in dict.sorted(by: { $0.key < $1.key }) {
            if out.count >= 64 { break }
            if let s = v as? String, s.count > 1000 { out[String(k.prefix(64))] = String(s.prefix(1000)) }
            else { out[String(k.prefix(64))] = sanitize(v) }
        }
        return out
    }
}
