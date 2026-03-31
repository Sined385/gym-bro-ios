//
//  BodyMeasurementModel.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import SwiftData

/// SwiftData model for tracking body measurements over time
@Model
final class BodyMeasurementModel {
    @Attribute(.unique) var id: UUID
    var date: Date
    var weight: Double? // in kilograms
    var bodyFatPercentage: Double? // 0-100
    var leanBodyMass: Double? // in kilograms
    var bmi: Double?
    var notes: String?
    var isSyncedToHealthKit: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        weight: Double? = nil,
        bodyFatPercentage: Double? = nil,
        leanBodyMass: Double? = nil,
        bmi: Double? = nil,
        notes: String? = nil,
        isSyncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.leanBodyMass = leanBodyMass
        self.bmi = bmi
        self.notes = notes
        self.isSyncedToHealthKit = isSyncedToHealthKit
    }
}
