import Foundation

/// What a server response means for the SDK (see PROTOCOL.md, "Responses and retries").
enum SendResult: Equatable {
    case ok
    case drop
    case unauthorized
    case tooLarge
    case retry(after: TimeInterval?)

    static func from(status: Int, retryAfter: String?) -> SendResult {
        switch status {
        case 200...299: return .ok
        case 401, 403: return .unauthorized
        case 413: return .tooLarge
        case 429, 500...599: return .retry(after: retryAfter.flatMap { TimeInterval($0) })
        default: return .drop
        }
    }
}

final class Transport {
    private let endpoint: URL
    private let configEndpoint: URL
    private let key: String
    private let session: URLSession

    init(baseURL: URL, key: String) {
        endpoint = baseURL.appendingPathComponent("cx/v1/batch")
        configEndpoint = baseURL.appendingPathComponent("cx/v1/config")
        self.key = key
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 30
        session = URLSession(configuration: cfg)
    }

    /// Synchronous send: called on the SDK's serial queue (NOT on the main thread).
    func send(_ body: Data) -> SendResult {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.httpBody = body
        req.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        req.setValue(key, forHTTPHeaderField: "X-Colay-Key")
        req.setValue("colay-ios/\(ColaySDKVersion)", forHTTPHeaderField: "User-Agent")

        let sem = DispatchSemaphore(value: 0)
        var result: SendResult = .retry(after: nil)
        session.dataTask(with: req) { _, response, error in
            if error == nil, let http = response as? HTTPURLResponse {
                result = SendResult.from(status: http.statusCode, retryAfter: http.value(forHTTPHeaderField: "Retry-After"))
            }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 35)
        return result
    }

    /// SDK settings from the server (SKAdNetwork schema). Synchronous, on the SDK's serial queue. nil on failure.
    func fetchConfig() -> Data? {
        var req = URLRequest(url: configEndpoint)
        req.httpMethod = "GET"
        req.setValue(key, forHTTPHeaderField: "X-Colay-Key")
        req.setValue("colay-ios/\(ColaySDKVersion)", forHTTPHeaderField: "User-Agent")

        let sem = DispatchSemaphore(value: 0)
        var out: Data?
        session.dataTask(with: req) { data, response, error in
            if error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200 { out = data }
            sem.signal()
        }.resume()
        _ = sem.wait(timeout: .now() + 20)
        return out
    }
}
