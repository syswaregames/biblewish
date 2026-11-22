//
//  AppDelegate.swift
//
//  The parts of push that Apple hands to an app delegate: the device token, a notification arriving
//  while the app is open, and a tap on one.
//

import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Task { @MainActor in PushManager.shared.didRegister(deviceToken: deviceToken) }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        Task { @MainActor in PushManager.shared.didFailToRegister(error) }
    }

    /// Open app: still show the banner (the bell's count refreshes too).
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        NotificationCenter.default.post(name: .bibleWishPushArrived, object: nil)
        return [.banner, .list, .sound, .badge]
    }

    /// A tap: go where the notification points ("url" from the server). The daily verse reminder,
    /// made on the phone, has none and opens Home.
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let url = response.notification.request.content.userInfo["url"] as? String
        await MainActor.run { AppRouter.shared.open(PushRoute.parse(url)) }
    }
}
