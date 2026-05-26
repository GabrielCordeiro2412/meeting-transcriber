import AppKit
import SwiftUI

struct FloatingWidgetView: View {
    @EnvironmentObject private var coordinator: MeetingCoordinator

    private var widgetShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: coordinator.widgetCornerRadius, style: .continuous)
    }

    var body: some View {
        ZStack {
            widgetBackground

            HStack(spacing: 16) {
                captureSection
                controlCluster
            }
            .padding(.leading, 22)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .padding(.top, 8)
        }
        .frame(
            width: coordinator.widgetSize.width,
            height: coordinator.widgetSize.height
        )
        .clipShape(widgetShape)
        .overlay(
            widgetShape
                .stroke(Color.white.opacity(coordinator.recordingState == .recording ? 0.22 : 0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.22), value: coordinator.recordingState)
    }

    private var widgetBackground: some View {
        ZStack {
            VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(widgetShape)

            widgetShape
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.13, blue: 0.18).opacity(0.64),
                            Color(red: 0.10, green: 0.18, blue: 0.24).opacity(0.58),
                            Color(red: 0.13, green: 0.24, blue: 0.29).opacity(0.52)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.cyan.opacity(0.14))
                    .frame(width: 180, height: 180)
                    .blur(radius: 26)
                    .offset(x: -34, y: -60)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 150, height: 150)
                    .blur(radius: 28)
                    .offset(x: 42, y: 42)
            }
            .overlay {
                widgetShape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blur(radius: 14)
                    .padding(10)
                    .clipShape(widgetShape)
            }
    }

    private var controlCluster: some View {
        HStack(spacing: 8) {
            if coordinator.completionMessage != nil {
                Button {
                    coordinator.showHistoryWindow(sessionId: coordinator.selectedSession?.id)
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                }
                .buttonStyle(CircularGlassIconButtonStyle(tint: .green, diameter: 34))
                .help("Open summary")
                .accessibilityLabel("Open summary")

                Button {
                    coordinator.resetCompletionState()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(CircularGlassIconButtonStyle(tint: .cyan, diameter: 34))
                .help("Start a new recording")
                .accessibilityLabel("Start a new recording")
            } else {
                controlButton
            }

            if coordinator.canDiscardRecording {
                Button {
                    Task { await coordinator.discardRecording() }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(CircularGlassIconButtonStyle(tint: .red, diameter: 34))
                .help("Stop and discard")
                .accessibilityLabel("Stop and discard")
                .transition(.scale.combined(with: .opacity))
            }

            if coordinator.completionMessage == nil {
                Button {
                    Task { await coordinator.finishRecording() }
                } label: {
                    Image(systemName: "text.badge.checkmark")
                }
                .buttonStyle(CircularGlassIconButtonStyle(tint: .green, diameter: 34))
                .disabled(!coordinator.canFinishRecording)
                .opacity(coordinator.canFinishRecording ? 1 : 0.38)
                .help(coordinator.canFinishRecording ? "Finish and transcribe" : "Record audio before transcribing")
                .accessibilityLabel("Finish and transcribe")
            }
        }
        .animation(.easeInOut(duration: 0.18), value: coordinator.canDiscardRecording)
    }

    private var captureSection: some View {
        HStack(spacing: 10) {
            if coordinator.completionMessage != nil {
                completionPill
            } else {
                captureIndicator
            }
            timerSlot
        }
    }

    private var completionPill: some View {
        Label("Summary ready", systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.94))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(Color.green.opacity(0.22), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
            .frame(width: captureWidth, alignment: .leading)
    }

    private var captureIndicator: some View {
        VoiceActivityView(
            level: coordinator.inputLevel,
            isActive: coordinator.recordingState == .recording
        )
        .frame(width: captureWidth)
    }

    private var captureWidth: CGFloat {
        switch coordinator.recordingState {
        case .recording, .paused:
            160
        case .processingTranscript, .generatingSummary:
            160
        default:
            160
        }
    }

    @ViewBuilder
    private var timerSlot: some View {
        if coordinator.recordingState == .recording || coordinator.recordingState == .paused {
            CompactRecordingDurationLabel(
                baseElapsed: coordinator.accumulatedRecordingDuration,
                startedAt: coordinator.recordingStartedAt
            )
        } else if coordinator.recordingState == .processingTranscript || coordinator.recordingState == .generatingSummary {
            processingPill
        }
    }

    private var processingPill: some View {
        Text(coordinator.recordingState.label)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.78))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }

    @ViewBuilder
    private var controlButton: some View {
        if coordinator.canPauseRecording {
            Button {
                Task { await coordinator.pauseRecording() }
            } label: {
                Image(systemName: "pause.fill")
            }
            .buttonStyle(CircularGlassIconButtonStyle(tint: coordinator.recordingState.tint, diameter: 34))
            .help("Pause")
            .accessibilityLabel("Pause")
        } else if coordinator.canResumeRecording {
            Button {
                Task { await coordinator.resumeRecording() }
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(CircularGlassIconButtonStyle(tint: coordinator.recordingState.tint, diameter: 34))
            .help("Resume")
            .accessibilityLabel("Resume")
        } else {
            Button {
                Task { await coordinator.startRecording() }
            } label: {
                Image(systemName: "mic.fill")
            }
            .buttonStyle(CircularGlassIconButtonStyle(tint: coordinator.recordingState.tint, diameter: 34))
            .disabled(!coordinator.canStartRecording)
            .help("Start recording")
            .accessibilityLabel("Start recording")
        }
    }
}

private struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        view.wantsLayer = true
        view.layer?.masksToBounds = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}
