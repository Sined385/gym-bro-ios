//
//  AppDelegate.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-24.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        configureFirebase()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    /// Each Firebase iOS app entry is bound to a single bundle id. Staging and
    /// prod ship separate plists (`GoogleService-Info-Staging.plist` for
    /// `*.staging`, `GoogleService-Info.plist` for prod). Pick the right one
    /// at runtime from the running bundle id — no build phases, no fragile
    /// per-config file swapping.
    private func configureFirebase() {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let plistName = bundleID.contains(".staging")
            ? "GoogleService-Info-Staging"
            : "GoogleService-Info"
        guard
            let path = Bundle.main.path(forResource: plistName, ofType: "plist"),
            let options = FirebaseOptions(contentsOfFile: path)
        else {
            assertionFailure("Missing \(plistName).plist for bundle \(bundleID)")
            FirebaseApp.configure()
            return
        }
        FirebaseApp.configure(options: options)
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - MessagingDelegate

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        Task { @MainActor in
            let pushService = DependencyContainer.shared.resolve(PushNotificationService.self)
            await pushService.registerToken(token)
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Coach replies fire every time the assistant finishes a message.
        // While the app is in foreground the SSE stream already delivers
        // the content live — suppress the banner so the user doesn't see
        // a notification for something they're actively reading.
        let userInfo = notification.request.content.userInfo
        if (userInfo["type"] as? String) == "coach_reply" {
            return []
        }
        return [.banner, .sound, .badge]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run {
            let router = DependencyContainer.shared.resolve(DeepLinkRouter.self)
            router.handlePushNotification(userInfo: userInfo)
        }
    }
}

