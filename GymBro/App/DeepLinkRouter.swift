//
//  DeepLinkRouter.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-02.
//

import Foundation
import Combine

enum DeepLink: Equatable {
    case sharedTemplate(code: String)
    case post(postId: String)
    case userProfile(userId: String)
    case skipRest
    case repeatLastSet
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    @Published var pendingPostId: String?
    @Published var pendingUserId: String?

    private static let allowedHosts: Set<String> = [
        "gyymjaam.com",
        "gym-bro-api-staging.up.railway.app"
    ]

    func handle(url: URL) -> Bool {
        // Handle gymjam:// scheme (Live Activity deep links)
        if url.scheme == "gymjam" {
            switch url.host {
            case "skip-rest":
                pendingDeepLink = .skipRest
                return true
            case "repeat-last-set":
                pendingDeepLink = .repeatLastSet
                return true
            default:
                return false
            }
        }

        guard let host = url.host, Self.allowedHosts.contains(host),
              url.pathComponents.count == 3 else { return false }

        let prefix = url.pathComponents[1]
        let value = url.pathComponents[2]

        switch prefix {
        case "s":
            pendingDeepLink = .sharedTemplate(code: value)
        case "p":
            pendingDeepLink = .post(postId: value)
        default:
            return false
        }
        return true
    }

    func handlePushNotification(userInfo: [AnyHashable: Any]) {
        let type = userInfo["type"] as? String
        let postId = userInfo["postId"] as? String
        let userId = userInfo["userId"] as? String

        switch type {
        case "new_post", "like", "comment":
            if let postId {
                pendingDeepLink = .post(postId: postId)
            }
        case "follow":
            if let userId {
                pendingDeepLink = .userProfile(userId: userId)
            }
        default:
            if let postId {
                pendingDeepLink = .post(postId: postId)
            }
        }
    }

    func clearDeepLink() {
        pendingDeepLink = nil
    }
}
