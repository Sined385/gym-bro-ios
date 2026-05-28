//
//  DailyChallengeNotificationScheduler.swift
//  GymBro
//
//  Schedules a local notification for tomorrow at 9am with the upcoming
//  daily challenge's title + description. Re-runs every time Home loads
//  so the scheduled body stays in sync with whatever the server says
//  tomorrow's challenge is.
//

import Foundation
import UserNotifications

enum DailyChallengeNotificationScheduler {
    private static let identifier = "daily_challenge_reminder"
    private static let fireHour = 9

    /// Schedules (or refreshes) tomorrow's 9am notification. No-op if
    /// `challenge` is nil. Re-requests authorization if it has never been
    /// granted — the OS shows the prompt at most once.
    static func schedule(for challenge: DailyChallenge?) {
        guard let challenge else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Today's challenge: \(challenge.title)"
            content.body = challenge.description
            content.sound = .default
            content.userInfo = ["challenge_id": challenge.id]

            var dateComponents = DateComponents()
            dateComponents.hour = fireHour
            dateComponents.minute = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

            let request = UNNotificationRequest(
                identifier: identifier,
                content: content,
                trigger: trigger
            )

            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            center.add(request)
        }
    }
}
