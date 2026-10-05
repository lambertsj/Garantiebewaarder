import SwiftUI

/// Drie korte schermen; overslaan kan altijd. Vraagt hier geen toestemmingen.
struct OnboardingView: View {
    let finish: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let title: LocalizedStringKey
        let message: LocalizedStringKey
    }

    private let pages = [
        Page(id: 0, symbol: "doc.text.viewfinder", title: "onboarding.1.title", message: "onboarding.1.message"),
        Page(id: 1, symbol: "lock.shield", title: "onboarding.2.title", message: "onboarding.2.message"),
        Page(id: 2, symbol: "bell.badge", title: "onboarding.3.title", message: "onboarding.3.message"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("onboarding.skip", action: finish)
                    .accessibilityIdentifier("onboardingSkip")
                    .padding()
            }
            TabView(selection: $page) {
                ForEach(pages) { item in
                    VStack(spacing: 20) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 72))
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        Text(item.title).font(.title.bold()).multilineTextAlignment(.center)
                        Text(item.message).font(.body).foregroundStyle(Theme.secondaryText).multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 32)
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(action: next) {
                Text(page == pages.count - 1 ? "onboarding.start" : "onboarding.next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(24)
            .accessibilityIdentifier("onboardingNext")
        }
        .background(Color(.systemBackground))
    }

    private func next() {
        if page < pages.count - 1 {
            withAnimation { page += 1 }
        } else {
            finish()
        }
    }
}

#if DEBUG
#Preview { OnboardingView {} }
#endif
