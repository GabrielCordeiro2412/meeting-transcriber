import SwiftData
import SwiftUI
import UserNotifications
import Carbon.HIToolbox.Events

@main
struct MeetingNotesApp: App {
    @NSApplicationDelegateAdaptor(MeetingNotesAppDelegate.self) private var appDelegate
    private let modelContainer: ModelContainer
    @StateObject private var coordinator: MeetingCoordinator

    init() {
        let schema = Schema([MeetingSession.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let container = Self.loadModelContainer(schema: schema, configuration: configuration)
        self.modelContainer = container

        let store = SwiftDataMeetingSessionStore(modelContainer: container)
        let coordinator = MeetingCoordinator(store: store)
        _coordinator = StateObject(wrappedValue: coordinator)
        appDelegate.coordinator = coordinator
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(coordinator)
                .modelContainer(modelContainer)
        } label: {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .symbolRenderingMode(.hierarchical)
                .help("Meeting Notes")
        }
        .menuBarExtraStyle(.window)
    }

    private static func loadModelContainer(schema: Schema, configuration: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            recoverIncompatibleStoreIfNeeded()

            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Unable to load SwiftData container after recovery attempt: \(error)")
            }
        }
    }

    private static func recoverIncompatibleStoreIfNeeded() {
        let fileManager = FileManager.default
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let storeURL = baseURL?.appendingPathComponent("default.store") else {
            return
        }

        let relatedURLs = [
            storeURL,
            storeURL.appendingPathExtension("shm"),
            storeURL.appendingPathExtension("wal"),
        ]

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        for url in relatedURLs where fileManager.fileExists(atPath: url.path) {
            let backupURL = url.deletingPathExtension()
                .appendingPathExtension("\(timestamp).backup")
                .appendingPathExtension(url.pathExtension)

            try? fileManager.moveItem(at: url, to: backupURL)
        }
    }
}

final class MeetingNotesAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var coordinator: MeetingCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }

        let openAction = UNNotificationAction(
            identifier: MeetingNotificationManager.openActionIdentifier,
            title: "Open Summary",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: MeetingNotificationManager.categoryIdentifier,
            actions: [openAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([category])

        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURLEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let shouldOpen = response.actionIdentifier == MeetingNotificationManager.openActionIdentifier
            || response.actionIdentifier == UNNotificationDefaultActionIdentifier
        if shouldOpen,
           let rawSessionID = response.notification.request.content.userInfo["sessionId"] as? String,
           let sessionID = UUID(uuidString: rawSessionID) {
            let coordinator = self.coordinator
            Task { @MainActor [weak coordinator] in
                coordinator?.showHistoryWindow(sessionId: sessionID)
            }
        }

        completionHandler()
    }

    @objc private func handleGetURLEvent(_ event: NSAppleEventDescriptor, withReplyEvent: NSAppleEventDescriptor) {
        guard let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: urlString) else {
            return
        }

        let coordinator = self.coordinator
        Task { @MainActor [weak coordinator] in
            await coordinator?.handleAuthenticationCallback(url: url)
        }
    }
}
