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
}

@MainActor
final class DeepLinkRouter: ObservableObject {
    @Published var pendingDeepLink: DeepLink?

    private static let allowedHosts: Set<String> = [
        "gyymjaam.com",
        "gym-bro-api-staging.up.railway.app"
    ]

    func handle(url: URL) -> Bool {
        guard let host = url.host, Self.allowedHosts.contains(host),
              url.pathComponents.count == 3,
              url.pathComponents[1] == "s" else { return false }
        pendingDeepLink = .sharedTemplate(code: url.pathComponents[2])
        return true
    }

    func clearDeepLink() {
        pendingDeepLink = nil
    }
}
