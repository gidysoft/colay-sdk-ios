import SwiftUI
import ColaySDK

/// Application entry point.
///
/// **Step 1 — Initialize the SDK.** Call `Colay.start` once when the app launches.
/// - Key: Dashboard → Ads → Tracking setup → iOS source (starts with `colay_pk_`; it is not a secret).
///   This example reads it through `Config.xcconfig` → Info.plist (`COLAY_KEY`, `COLAY_BASE_URL`).
/// - For users covered by GDPR/KVKK, start with `.denied` until explicit consent is given; call
///   `Colay.setConsent` after the consent screen (here: `MainViewModel`).
/// - The SDK never requests ATT permission.
@main
struct ColayExampleApp: App {
    init() {
        let info = Bundle.main.infoDictionary ?? [:]
        var config = ColayConfig()
        if let base = info["COLAY_BASE_URL"] as? String, let url = URL(string: base) { config.baseURL = url }
        config.defaultConsent = .denied
        config.flushAt = 5          // send quickly in the example (default is 20)
        config.flushInterval = 5
        #if DEBUG
        config.debug = true         // verbose console logging with the "[ColaySDK]" prefix
        #endif
        Colay.start(key: info["COLAY_KEY"] as? String ?? "", config: config)
    }

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(tracker: ColayAnalyticsTracker()))
                // Step 7 — Deep links: campaign data (UTM, fbclid, gclid…) is read
                .onOpenURL { Colay.handleDeepLink($0) }
        }
    }
}
