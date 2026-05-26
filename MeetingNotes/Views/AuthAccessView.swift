import SwiftUI

struct AuthAccessView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Sign in to Meeting Notes", systemImage: "person.badge.key")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Use your account to sign in. Audio processing runs through the Meeting Notes backend, and the desktop app never asks for an API key.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.82))

            TextField("you@example.com", text: $email)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Button {
                Task { await coordinator.sendMagicLink(email: email) }
            } label: {
                Label("Send Magic Link", systemImage: "paperplane.fill")
            }
            .buttonStyle(PrimaryGlassButtonStyle(tint: .cyan))
            .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.isAuthenticating)

            if !coordinator.statusMessage.isEmpty {
                Text(coordinator.statusMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
        .padding(18)
    }
}
