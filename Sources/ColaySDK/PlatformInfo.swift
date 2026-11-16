import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AdServices)
import AdServices
#endif
#if canImport(AdSupport)
import AdSupport
#endif
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif
#if canImport(StoreKit)
import StoreKit
#endif

enum PlatformInfo {

    static func app() -> [String: Any] {
        let info = Bundle.main.infoDictionary ?? [:]
        return [
            "id": Bundle.main.bundleIdentifier ?? "",
            "version": info["CFBundleShortVersionString"] as? String ?? "",
            "build": info["CFBundleVersion"] as? String ?? "",
        ]
    }

    static func device() -> [String: Any] {
        var d: [String: Any] = [
            "platform": "ios",
            "manufacturer": "Apple",
            "model": modelIdentifier(),
            "locale": Locale.preferredLanguages.first ?? Locale.current.identifier,
            "timezone": TimeZone.current.identifier,
        ]
        #if canImport(UIKit) && !os(watchOS)
        let screen = UIScreen.main.nativeBounds
        d["os"] = UIDevice.current.systemName
        d["osVersion"] = UIDevice.current.systemVersion
        d["screenWidth"] = Int(screen.width)
        d["screenHeight"] = Int(screen.height)
        #else
        d["os"] = "macOS"
        d["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        #endif
        return d
    }

    /// For example "iPhone16,2".
    static func modelIdentifier() -> String {
        var sys = utsname()
        uname(&sys)
        return withUnsafeBytes(of: &sys.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// IDFA: only if the user granted ATT permission. Permission is NEVER requested.
    static func advertisingId() -> String? {
        #if canImport(AdSupport) && canImport(AppTrackingTransparency) && os(iOS)
        if #available(iOS 14, *) {
            guard ATTrackingManager.trackingAuthorizationStatus == .authorized else { return nil }
        }
        let id = ASIdentifierManager.shared().advertisingIdentifier.uuidString
        return id == "00000000-0000-0000-0000-000000000000" ? nil : id
        #else
        return nil
        #endif
    }

    /// Apple Search Ads attribution token (iOS 14.3+, no ATT required). The server resolves it with Apple.
    static func appleSearchAdsToken() -> String? {
        #if canImport(AdServices) && os(iOS)
        if #available(iOS 14.3, *) {
            return try? AAAttribution.attributionToken()
        }
        #endif
        return nil
    }

    /// Updates the SKAdNetwork / AdAttributionKit conversion value (0-63).
    static func updateConversionValue(_ fine: Int, coarse: ColayCoarseValue?, lockWindow: Bool) {
        #if canImport(StoreKit) && os(iOS)
        let value = max(0, min(63, fine))
        if #available(iOS 16.1, *) {
            let c: SKAdNetwork.CoarseConversionValue
            switch coarse ?? .low {
            case .low: c = .low
            case .medium: c = .medium
            case .high: c = .high
            }
            SKAdNetwork.updatePostbackConversionValue(value, coarseValue: c, lockWindow: lockWindow) { _ in }
        } else if #available(iOS 15.4, *) {
            SKAdNetwork.updatePostbackConversionValue(value) { _ in }
        } else if #available(iOS 14.0, *) {
            SKAdNetwork.updateConversionValue(value)
        }
        #endif
    }
}

/// SKAdNetwork 4 coarse conversion value.
public enum ColayCoarseValue {
    case low, medium, high
}
