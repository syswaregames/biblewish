//
//  PushManager.swift
//
//  Push notifications from biblewish.com: asks permission, gets this phone's token from Apple and
//  keeps the server told about it while someone is signed in. The server sends (api/devices.php,
//  api/lib/push.php); nothing is sent until the site has Apple's key, and the app says so.
//

import SwiftUI
import UserNotifications

extension Notification.Name {
    /// A push arrived while the app was open: the bell's count is out of date.
    static let bibleWishPushArrived = Notification.Name("bibleWishPushArrived")
}

@MainActor
final class PushManager: ObservableObject {

    static let shared = PushManager()

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var token: String?
    /// Whether the server can send (it has Apple's key). Nil until asked.
    @Published private(set) var serverAvailable: Bool?
    @Published private(set) var isRegistered = false
    @Published private(set) var message: String?

    private let api = APIClient.shared
    private let tokenKey = "push_device_token_v1"

    private struct Summary: Decodable {
        struct Push: Decodable { let available: Bool }
        let devices: Int
        let push: Push
        let delivered: Int?
    }

    private init() {
        token = UserDefaults.standard.string(forKey: tokenKey)
    }

    var isAllowed: Bool {
        authorization == .authorized || authorization == .provisional || authorization == .ephemeral
    }

    // MARK: - Permission and token

    func refreshAuthorization() async {
        authorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Asks the reader (once) and, if allowed, asks Apple for this phone's token.
    func enable() async {
        message = nil
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            message = error.localizedDescription
        }
        await refreshAuthorization()
        if isAllowed { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// Called at launch and when the app opens: tokens can change, so ask again while allowed.
    func registerIfAllowed() async {
        await refreshAuthorization()
        if isAllowed { UIApplication.shared.registerForRemoteNotifications() }
    }

    func didRegister(deviceToken: Data) {
        let hex = PushEnvironment.hex(deviceToken)
        token = hex
        UserDefaults.standard.set(hex, forKey: tokenKey)
        Task { await syncRegistration() }
    }

    func didFailToRegister(_ error: Error) {
        // Normal in the simulator without an account, or on a build without the push capability.
        message = "This phone could not be registered for push: \(error.localizedDescription)"
    }

    // MARK: - The server

    /// Tells the server about this phone (the account it is signed into now).
    func syncRegistration() async {
        guard let token, isAllowed else { return }
        do {
            let summary = try await api.request(Summary.self, "POST", "api/devices.php", json: [
                "token": token,
                "environment": PushEnvironment.current,
                "app_version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            ])
            serverAvailable = summary.push.available
            isRegistered = summary.devices > 0
        } catch APIError.unauthorized {
            isRegistered = false
        } catch {
            // Offline or server trouble: try again at the next launch.
        }
    }

    /// Whether the server could send pushes if asked, and how many phones this account has.
    func refreshServerStatus() async {
        guard let summary = try? await api.request(Summary.self, "GET", "api/devices.php") else { return }
        serverAvailable = summary.push.available
        isRegistered = summary.devices > 0
    }

    /// Takes this phone off the account, before signing out.
    func unregister() async {
        guard let token else { return }
        _ = try? await api.send("DELETE", "api/devices.php", json: ["token": token])
        isRegistered = false
        setBadge(0)
    }

    /// Asks the server to push a test to this account's phones. Returns what to tell the reader.
    func sendTest() async -> String {
        guard isAllowed else { return "Allow notifications for BibleWish first." }
        guard token != nil else { return "This phone is not registered yet. Wait a moment and try again." }
        await syncRegistration()
        do {
            let summary = try await api.request(Summary.self, "POST", "api/devices.php", query: ["action": "test"])
            serverAvailable = summary.push.available
            if !summary.push.available { return "Push is not set up on the server yet, so nothing was sent." }
            return (summary.delivered ?? 0) > 0
                ? "Sent. It should arrive in a moment."
                : "Apple did not accept it for this phone. Try turning push off and on, then again."
        } catch {
            return CommunityStore.message(error)
        }
    }

    // MARK: - The icon's badge

    /// The app icon shows how many notifications are unread.
    func setBadge(_ count: Int) {
        guard isAllowed else { return }
        UNUserNotificationCenter.current().setBadgeCount(max(0, count))
    }
}
