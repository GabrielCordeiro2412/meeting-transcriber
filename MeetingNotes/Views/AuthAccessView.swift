import SwiftUI

struct APIKeySetupCard: View {
    let onConfigure: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("OpenAI API key required", systemImage: "key.fill")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("This open source app runs locally on your Mac. Add your own OpenAI API key to enable transcription and meeting summaries.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            Button(action: onConfigure) {
                Label("Configure OpenAI API Key", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(PrimaryGlassButtonStyle(tint: .cyan))
        }
        .padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct APIKeySettingsView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator
    let onBack: () -> Void

    @State private var apiKey = ""
    @State private var feedbackMessage: String?
    @FocusState private var isKeyFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryGlassButtonStyle())

            Label("OpenAI API Key", systemImage: "key.fill")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Your key is stored only in the macOS Keychain on this machine. Meeting recordings and generated notes remain local to your Mac.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            SecureField("sk-proj-...", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .focused($isKeyFieldFocused)

            HStack(spacing: 10) {
                Button {
                    saveAPIKey()
                } label: {
                    Label("Save Key", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(PrimaryGlassButtonStyle(tint: .cyan))
                .disabled(!APIKeyStore.isValidFormat(apiKey))

                Button {
                    clearAPIKey()
                } label: {
                    Label("Remove Key", systemImage: "trash")
                }
                .buttonStyle(SecondaryGlassButtonStyle())
                .disabled(!coordinator.hasAPIKey)
            }

            if let feedbackMessage {
                Text(feedbackMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.72))
            }
        }
        .onAppear {
            apiKey = coordinator.currentAPIKey
            feedbackMessage = nil
            isKeyFieldFocused = true
        }
    }

    private func saveAPIKey() {
        coordinator.saveAPIKey(apiKey)
        apiKey = coordinator.currentAPIKey
        feedbackMessage = coordinator.statusMessage
    }

    private func clearAPIKey() {
        coordinator.clearAPIKey()
        apiKey = ""
        feedbackMessage = coordinator.statusMessage
    }
}

struct SummaryLanguageSettingsView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(SecondaryGlassButtonStyle())

            Label("Summary Language", systemImage: "globe")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Choose the language used for titles, summaries, and structured notes. Transcription still follows the spoken language.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            Picker("Summary language", selection: summaryLanguageBinding) {
                ForEach(SummaryLanguagePreference.allCases, id: \.self) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()

            Text(coordinator.summaryLanguagePreference.detail)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.72))
        }
    }

    private var summaryLanguageBinding: Binding<SummaryLanguagePreference> {
        Binding(
            get: { coordinator.summaryLanguagePreference },
            set: { coordinator.setSummaryLanguagePreference($0) }
        )
    }
}
