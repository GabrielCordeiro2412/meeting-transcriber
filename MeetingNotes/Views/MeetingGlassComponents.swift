import AppKit
import SwiftUI

struct GlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    @ViewBuilder var content: Content

    init(cornerRadius: CGFloat = 28, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
    }
}

struct AmbientGlassBackground: View {
    var body: some View {
        ZStack {
            SharedVisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow)

            LinearGradient(
                colors: [
                    Color(red: 0.09, green: 0.13, blue: 0.18).opacity(0.64),
                    Color(red: 0.10, green: 0.18, blue: 0.24).opacity(0.58),
                    Color(red: 0.13, green: 0.24, blue: 0.29).opacity(0.52)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: -110, y: -100)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 200, height: 200)
                .blur(radius: 32)
                .offset(x: 130, y: 118)

            RoundedRectangle(cornerRadius: 30, style: .continuous)
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
        }
        .ignoresSafeArea()
    }
}

struct SharedVisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = .active
    }
}

struct StatusHalo: View {
    let state: RecordingState
    let label: String

    var body: some View {
        ZStack {
            Circle()
                .fill(state.tint.opacity(0.22))
                .frame(width: 92, height: 92)
                .blur(radius: 10)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [state.tint.opacity(0.92), state.tint.opacity(0.42)],
                        center: .center,
                        startRadius: 6,
                        endRadius: 44
                    )
                )
                .frame(width: 74, height: 74)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.38), lineWidth: 1)
                )

            VStack(spacing: 4) {
                Image(systemName: state.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .textCase(.uppercase)
            }
        }
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let systemImage: String
    var multilineValue = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .frame(width: 26, height: 26)
                .background(Color.white.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.72))
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(multilineValue ? 2 : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

struct PrimaryGlassButtonStyle: ButtonStyle {
    let tint: Color
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.58))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(isEnabled ? (configuration.isPressed ? 0.7 : 0.95) : 0.22),
                                tint.opacity(isEnabled ? (configuration.isPressed ? 0.45 : 0.72) : 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.22 : 0.08), lineWidth: 1)
            )
            .shadow(color: tint.opacity(isEnabled ? (configuration.isPressed ? 0.12 : 0.28) : 0), radius: 16, y: 10)
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.76)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryGlassButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(isEnabled ? 0.95 : 0.52))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(
                Color.white.opacity(
                    isEnabled ? (configuration.isPressed ? 0.13 : 0.08) : 0.04
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.12 : 0.06), lineWidth: 1)
            )
            .scaleEffect(isEnabled && configuration.isPressed ? 0.985 : 1)
            .opacity(isEnabled ? 1 : 0.74)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct CircularGlassIconButtonStyle: ButtonStyle {
    let tint: Color
    var diameter: CGFloat = 42

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: diameter, height: diameter)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tint.opacity(configuration.isPressed ? 0.68 : 0.94),
                                tint.opacity(configuration.isPressed ? 0.42 : 0.7)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: tint.opacity(configuration.isPressed ? 0.12 : 0.24), radius: 14, y: 8)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct LivePulseDot: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.22))
                .frame(width: 18, height: 18)
                .scaleEffect(animate ? 1.8 : 0.7)
                .opacity(animate ? 0.05 : 0.4)

            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }
}

struct RecordingDurationLabel: View {
    let baseElapsed: TimeInterval
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 8) {
                Image(systemName: "timer")
                    .font(.system(size: 11, weight: .semibold))
                Text(elapsedText(now: context.date))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(Color.white.opacity(0.92))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1), in: Capsule())
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
        }
    }

    private func elapsedText(now: Date) -> String {
        let liveElapsed = startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let elapsed = max(0, Int(baseElapsed + liveElapsed))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct CompactRecordingDurationLabel: View {
    let baseElapsed: TimeInterval
    let startedAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Text(elapsedText(now: context.date))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.white.opacity(0.94))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.18), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    private func elapsedText(now: Date) -> String {
        let liveElapsed = startedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0
        let elapsed = max(0, Int(baseElapsed + liveElapsed))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

struct VoiceActivityView: View {
    let level: Float
    let isActive: Bool
    private let barCount = 18

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isActive)) { context in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(barGradient(index: index))
                        .frame(width: 4, height: barHeight(index: index, time: context.date.timeIntervalSinceReferenceDate))
                }
            }
            .padding(.horizontal, 10)
            .frame(minHeight: 44, maxHeight: 44, alignment: .center)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isActive else { return 8 }
        let phase = sin(time * 7 + Double(index) * 0.55)
        let shaped = max(0.18, CGFloat(level) * 0.9 + CGFloat((phase + 1) / 2) * 0.45)
        return min(34, 8 + shaped * 24)
    }

    private func barGradient(index: Int) -> LinearGradient {
        let hueShift = Double(index) / Double(max(barCount - 1, 1))
        let top = Color(hue: 0.49 + hueShift * 0.06, saturation: 0.5, brightness: 0.98)
        let bottom = Color(hue: 0.56 + hueShift * 0.04, saturation: 0.72, brightness: 0.88)
        return LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
    }
}

extension RecordingState {
    var tint: Color {
        switch self {
        case .idle:
            Color.cyan
        case .requestingPermissions:
            Color.orange
        case .recording:
            Color.red
        case .paused:
            Color.yellow
        case .processingTranscript:
            Color.blue
        case .generatingSummary:
            Color.teal
        case .completed:
            Color.green
        case .error:
            Color.pink
        }
    }

    var actionTitle: String {
        switch self {
        case .idle, .completed, .error:
            "Start Session"
        case .requestingPermissions:
            "Waiting"
        case .recording:
            "Pause Session"
        case .paused:
            "Resume Session"
        case .processingTranscript:
            "Transcribing"
        case .generatingSummary:
            "Summarizing"
        }
    }
}
