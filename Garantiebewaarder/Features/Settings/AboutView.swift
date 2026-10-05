import SwiftUI

/// "Over deze app": privacyverhaal in gewone taal, versie en feedback.
struct AboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppInfo.name).font(.title2.bold())
                    Text("about.version \(AppInfo.version)").font(.subheadline).foregroundStyle(Theme.secondaryText)
                }
                .accessibilityElement(children: .combine)
                Text("about.free")
            }

            Section("about.privacy.title") {
                bullet("lock.shield", "about.privacy.1")
                bullet("icloud", "about.privacy.2")
                bullet("eye.slash", "about.privacy.3")
                bullet("wifi.slash", "about.privacy.4")
            }

            Section {
                if let url = feedbackURL {
                    Button { openURL(url) } label: { Label("about.feedback", systemImage: "envelope") }
                        .accessibilityIdentifier("feedbackButton")
                }
            } footer: {
                Text("about.feedback.footer")
            }
        }
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bullet(_ symbol: String, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
        }
    }

    private var feedbackURL: URL? {
        ClaimEmailTemplate.mailtoURL(
            for: .init(subject: "\(AppInfo.name) \(AppInfo.version)", body: ""),
            recipient: AppInfo.feedbackEmail
        )
    }
}
