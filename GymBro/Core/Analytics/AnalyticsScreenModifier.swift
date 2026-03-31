//
//  AnalyticsScreenModifier.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-30.
//

import SwiftUI
import FirebaseAnalytics

extension View {
    func analyticsScreen(_ name: String) -> some View {
        self.onAppear {
            Analytics.logEvent(AnalyticsEventScreenView, parameters: [
                AnalyticsParameterScreenName: name,
                AnalyticsParameterScreenClass: name
            ])
        }
    }
}
