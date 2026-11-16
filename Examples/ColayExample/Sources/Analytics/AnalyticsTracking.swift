import Foundation

/// Abstraction over the app's analytics needs.
///
/// ViewModels depend on this protocol rather than on the SDK directly, so tests can pass a fake implementation
/// and adding another analytics tool later does not change the ViewModel.
protocol AnalyticsTracking {
    func setConsent(analytics: Bool, ads: Bool)
    func screen(_ name: String, properties: [String: Any])
    func track(_ event: String, properties: [String: Any])
    func identify(_ userId: String, traits: [String: Any])
    func purchase(_ amount: Double, currency: String, properties: [String: Any])
    func flush(completion: @escaping () -> Void)
    func reset()
}
