import AppKit
import SwiftUI

@MainActor
final class FloatingWidgetController {
    private var panel: NSPanel?
    private var currentCornerRadius: CGFloat = 28
    private let trafficLightTopInset: CGFloat = 8
    private let trafficLightLeadingInset: CGFloat = 14
    private let trafficLightSpacing: CGFloat = 6

    func show(coordinator: MeetingCoordinator) {
        if let panel {
            panel.makeKeyAndOrderFront(nil)
            updateLayout(size: coordinator.widgetSize)
            return
        }

        let rootView = FloatingWidgetView()
            .environmentObject(coordinator)
        currentCornerRadius = coordinator.widgetCornerRadius
        let hostingView = NSHostingView(rootView: rootView)
        configureContentMask(for: hostingView, cornerRadius: coordinator.widgetCornerRadius)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: coordinator.widgetSize),
            styleMask: [.nonactivatingPanel, .titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Meeting Notes"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
        panel.center()
        layoutTrafficLights(in: panel)
        panel.orderFrontRegardless()

        self.panel = panel
    }

    func updateLayout(size: CGSize) {
        guard let panel else { return }
        var frame = panel.frame
        frame.origin.y += frame.size.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true, animate: false)
        if let contentView = panel.contentView {
            contentView.frame = NSRect(origin: .zero, size: size)
            contentView.layer?.cornerRadius = currentCornerRadius
        }
        layoutTrafficLights(in: panel)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func layoutTrafficLights(in panel: NSPanel) {
        let buttons: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
        var x = trafficLightLeadingInset
        let buttonHost = panel.standardWindowButton(.closeButton)?.superview

        for buttonType in buttons {
            guard let button = panel.standardWindowButton(buttonType) else { continue }
            guard let host = button.superview ?? buttonHost else { continue }

            let y = max(trafficLightTopInset, host.bounds.height - button.frame.height - trafficLightTopInset)
            button.setFrameOrigin(NSPoint(x: x, y: y))
            x += button.frame.width + trafficLightSpacing
        }
    }

    private func configureContentMask(for view: NSView, cornerRadius: CGFloat) {
        view.wantsLayer = true
        view.layer?.cornerRadius = cornerRadius
        view.layer?.cornerCurve = .continuous
        view.layer?.masksToBounds = true
        view.layer?.backgroundColor = NSColor.clear.cgColor
    }
}
