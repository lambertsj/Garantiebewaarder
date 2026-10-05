import SwiftUI

/// "Mijn product is kapot, wat nu?" Algemene informatie, geen juridisch advies.
/// Alle inhoudelijke teksten staan in `LegalContent` / de catalogus (`legal.*`).
struct ClaimHelpView: View {
    let product: Product

    @Environment(\.openURL) private var openURL
    @State private var message: ClaimEmailTemplate.Message

    init(product: Product) {
        self.product = product
        _message = State(initialValue: ClaimEmailTemplate.make(ClaimEmailTemplate.Input(
            productName: product.name, brand: product.brand, store: product.store,
            purchaseDate: product.purchaseDate, price: product.price, serialNumber: product.serialNumber
        )))
    }

    var body: some View {
        List {
            Section {
                Label(String(localized: LegalContent.generalInfo), systemImage: "info.circle")
                    .font(.footnote)
                    .accessibilityIdentifier("claimDisclaimer")
            }

            Section("claim.steps.title") {
                ForEach(LegalContent.claimSteps) { step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(step.number)")
                            .font(.headline)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.accentColor.opacity(0.15)))
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title).font(.headline)
                            Text(step.detail).font(.subheadline).foregroundStyle(Theme.secondaryText)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("claim.step.accessibility \(step.number)"))
                }
            }

            Section {
                TextField("claim.mail.subjectField", text: $message.subject, axis: .vertical)
                TextEditor(text: $message.body)
                    .frame(minHeight: 260)
                    .accessibilityLabel(Text("claim.mail.bodyField"))
                    .accessibilityIdentifier("claimBody")
                ShareLink(item: "\(message.subject)\n\n\(message.body)") {
                    Label("claim.mail.share", systemImage: "square.and.arrow.up")
                }
                if let url = ClaimEmailTemplate.mailtoURL(for: message) {
                    Button { openURL(url) } label: { Label("claim.mail.openMail", systemImage: "envelope") }
                }
            } header: {
                Text("claim.mail.title")
            } footer: {
                Text("claim.mail.footer")
            }

            if let url = LegalContent.officialSourceURL {
                Section {
                    Button { openURL(url) } label: {
                        Label("claim.officialSource \(LegalContent.officialSourceName)", systemImage: "safari")
                    }
                } footer: {
                    Text("claim.officialSource.footer")
                }
            }
        }
        .navigationTitle("claim.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
