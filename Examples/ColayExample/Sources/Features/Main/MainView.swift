import SwiftUI

/// Reads state from the ViewModel and forwards user actions to it. Contains no business logic.
struct MainView: View {
    @StateObject private var viewModel: MainViewModel

    init(viewModel: @autoclosure @escaping () -> MainViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Status")) {
                    Text(viewModel.lastAction).accessibilityIdentifier("status")
                    Text("Sent: \(viewModel.sentCount)").font(.caption).foregroundColor(.secondary)
                }
                Section(header: Text("Consent")) {
                    Button(viewModel.consentGranted ? "Withdraw consent" : "Grant consent (analytics and ads)", action: viewModel.toggleConsent)
                        .accessibilityIdentifier("consent")
                }
                Section(header: Text("Analytics calls")) {
                    Button("Screen: Product detail", action: viewModel.viewProduct).accessibilityIdentifier("viewProduct")
                    Button("Event: Add to cart", action: viewModel.addToCart).accessibilityIdentifier("addToCart")
                    Button("Event: Sign up", action: viewModel.signUp).accessibilityIdentifier("signUp")
                    Button("Purchase: 149.90 USD", action: viewModel.purchase).accessibilityIdentifier("purchase")
                }
                Section {
                    Button("Send now (flush)", action: viewModel.flush).accessibilityIdentifier("flush")
                    Button("Sign out (reset)", role: .destructive, action: viewModel.signOut).accessibilityIdentifier("signOut")
                }
            }
            .navigationTitle("Colay AI iOS SDK")
        }
        .onAppear(perform: viewModel.onAppear)
    }
}
