import SwiftUI

struct SettingsView: View {
    let store: UsageStore
    @State private var remote = ""
    @State private var token = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    field(Secrets.publicServer, text: $remote)
                    SecureField("X-Homebase-Token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                } header: {
                    Text("Server")
                } footer: {
                    Text("The claude-monitor backend on your Mac, shared with `homebase share --private`.")
                }
                Section {
                    Button("Reset to defaults") {
                        remote = Secrets.publicServer
                        token = Secrets.homebaseToken
                    }
                    .tint(Theme.peach)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.publicURL = remote
                        store.token = token
                        dismiss()
                        Task { await store.refresh(force: true) }
                    }
                    .bold()
                }
            }
            .onAppear {
                remote = store.publicURL
                token = store.token
            }
        }
        .tint(Theme.peach)
        .presentationDetents([.large])
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body.monospaced())
    }
}
