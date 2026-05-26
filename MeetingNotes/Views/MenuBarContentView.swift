import SwiftUI

struct MenuBarContentView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    var body: some View {
        ZStack {
            AmbientGlassBackground()

            ScrollView(.vertical, showsIndicators: true) {
                GlassPanel(cornerRadius: 30) {
                    if coordinator.isAuthenticated {
                        VStack(alignment: .leading, spacing: 16) {
                            hero
                            metrics
                            actions
                            utilityRow
                        }
                    } else {
                        AuthAccessView()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 380)
        .frame(minHeight: 430, maxHeight: 520)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            StatusHalo(state: coordinator.recordingState, label: coordinator.statusAccentLabel)
                .scaleEffect(0.92)

            VStack(alignment: .leading, spacing: 7) {
                Text("Meeting Notes")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(coordinator.recordingState.label)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(coordinator.recordingState.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.14), in: Capsule())

                Text(coordinator.statusMessage)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.84))
                    .lineLimit(3)

                if let completionMessage = coordinator.completionMessage {
                    VStack(spacing: 8) {
                        Button {
                            coordinator.showHistoryWindow(sessionId: coordinator.selectedSession?.id)
                        } label: {
                            Label(completionMessage, systemImage: "checkmark.circle.fill")
                                .lineLimit(2)
                        }
                        .buttonStyle(SecondaryGlassButtonStyle())
                        .help("Open the completed meeting summary")

                        Button {
                            coordinator.resetCompletionState()
                        } label: {
                            Label("Start New Recording", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(SecondaryGlassButtonStyle())
                        .help("Reset the widget and menu for a new recording")
                    }
                }

                if coordinator.canFinishRecording {
                    RecordingDurationLabel(
                        baseElapsed: coordinator.accumulatedRecordingDuration,
                        startedAt: coordinator.recordingStartedAt
                    )
                }
            }
        }
    }

    private var metrics: some View {
        VStack(spacing: 10) {
            MetricPill(
                title: "Library",
                value: "\(coordinator.completedSessionsCount) finished sessions",
                systemImage: "sparkles.rectangle.stack"
            )

            MetricPill(
                title: "Latest meeting",
                value: coordinator.latestSession?.title ?? "No meetings yet",
                systemImage: "clock.badge.checkmark",
                multilineValue: true
            )

            MetricPill(
                title: "Account",
                value: coordinator.userSession?.email ?? "Signed out",
                systemImage: "person.crop.circle",
                multilineValue: true
            )
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                controlButton

                Button {
                    Task { await coordinator.finishRecording() }
                } label: {
                    Label("Finish", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(SecondaryGlassButtonStyle())
                .disabled(!coordinator.canFinishRecording)
                .help(coordinator.canFinishRecording ? "Finish and transcribe this recording" : "Record or resume audio before finishing")
            }

            Button {
                Task { await coordinator.discardRecording() }
            } label: {
                Label("Stop & Discard", systemImage: "xmark.circle.fill")
            }
            .buttonStyle(SecondaryGlassButtonStyle())
            .disabled(!coordinator.canDiscardRecording)
            .help(coordinator.canDiscardRecording ? "Stop and discard the current recording" : "No active or paused recording to discard")

            HStack(spacing: 10) {
                Button {
                    coordinator.toggleFloatingWidget()
                } label: {
                    Label(
                        coordinator.isFloatingWidgetVisible ? "Hide Widget" : "Show Widget",
                        systemImage: coordinator.isFloatingWidgetVisible ? "rectangle.compress.vertical" : "rectangle.expand.vertical"
                    )
                }
                .buttonStyle(SecondaryGlassButtonStyle())

                Button {
                    coordinator.showHistoryWindow()
                } label: {
                    Label("History", systemImage: "text.append")
                }
                .buttonStyle(SecondaryGlassButtonStyle())
            }
        }
    }

    private var utilityRow: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()

                if coordinator.recordingState == .recording {
                    HStack(spacing: 8) {
                        LivePulseDot()
                        Text("Live")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.92))
                    }
                }
            }

            Button {
                coordinator.signOut()
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(SecondaryGlassButtonStyle())

            Button {
                coordinator.quitApp()
            } label: {
                Label("Quit App", systemImage: "power")
            }
            .buttonStyle(SecondaryGlassButtonStyle())
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    private var controlButton: some View {
        if coordinator.canPauseRecording {
            Button {
                Task { await coordinator.pauseRecording() }
            } label: {
                Label("Pause", systemImage: "pause.fill")
            }
            .buttonStyle(PrimaryGlassButtonStyle(tint: coordinator.recordingState.tint))
            .help("Pause the current recording")
        } else if coordinator.canResumeRecording {
            Button {
                Task { await coordinator.resumeRecording() }
            } label: {
                Label("Resume", systemImage: "play.fill")
            }
            .buttonStyle(PrimaryGlassButtonStyle(tint: coordinator.recordingState.tint))
            .help("Resume the paused recording")
        } else {
            Button {
                Task { await coordinator.startRecording() }
            } label: {
                Label("Start", systemImage: "mic.fill")
            }
            .buttonStyle(PrimaryGlassButtonStyle(tint: coordinator.recordingState.tint))
            .disabled(!coordinator.canStartRecording)
            .help(coordinator.canStartRecording ? "Start a new recording" : "Recording controls are temporarily unavailable")
        }
    }
}
