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
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingDeepLink: DeepLink?
    @Published var pendingPostId: String?

    private static let allowedHosts: Set<String> = [
        "gyymjaam.com",
        "gym-bro-api-staging.up.railway.app"
    ]

    func handle(url: URL) -> Bool {
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

    func clearDeepLink() {
        pendingDeepLink = nil
    }
}
