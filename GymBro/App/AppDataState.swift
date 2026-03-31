//
//  AppDataState.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-31.
//

import Foundation
import Combine

@MainActor
final class AppDataState: ObservableObject {
    @Published private(set) var reloadVersion: Int = 0

    func triggerReload() {
        reloadVersion += 1
    }
}
