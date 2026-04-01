//
//  AnalyticsTrackingService.swift
//  GymBro
//
//  Created by Claude Code on 2026-04-01.
//

import Foundation

// MARK: - Protocol

protocol AnalyticsTrackingServiceProtocol: AnyObject {
    func track(_ eventName: String, properties: [String: Any])
    func trackAppOpened()
    func trackAppBackgrounded()
    func trackTabSwitch(tab: String)
    func trackScreenView(screen: String)
    func flush()
}

// MARK: - Implementation

final class AnalyticsTrackingService: AnalyticsTrackingServiceProtocol {

    // MARK: - Properties

    private let networkService: NetworkServiceProtocol
    private var buffer: [(eventName: String, properties: [String: Any])] = []
    private let bufferLimit = 10
    private let flushInterval: TimeInterval = 30
    private var flushTimer: Timer?
    private let lock = NSLock()

    // MARK: - Init

    init(networkService: NetworkServiceProtocol) {
        self.networkService = networkService
        startFlushTimer()
    }

    deinit {
        flushTimer?.invalidate()
    }

    // MARK: - Tracking

    func track(_ eventName: String, properties: [String: Any] = [:]) {
        lock.lock()
        buffer.append((eventName: eventName, properties: properties))
        let shouldFlush = buffer.count >= bufferLimit
        lock.unlock()

        if shouldFlush {
            flush()
        }
    }

    func trackAppOpened() {
        track("app_opened")
    }

    func trackAppBackgrounded() {
        track("app_backgrounded")
    }

    func trackTabSwitch(tab: String) {
        track("tab_switched", properties: ["tab": tab])
    }

    func trackScreenView(screen: String) {
        track("screen_viewed", properties: ["screen": screen])
    }

    // MARK: - Flush

    func flush() {
        lock.lock()
        let events = buffer
        buffer.removeAll()
        lock.unlock()

        guard !events.isEmpty else { return }

        for event in events {
            Task {
                do {
                    try await networkService.request(
                        AnalyticsRouter.trackEvent(
                            eventName: event.eventName,
                            properties: event.properties
                        ).endpoint
                    )
                } catch {
                    // Fire-and-forget — don't block UI for analytics failures
                }
            }
        }
    }

    // MARK: - Private

    private func startFlushTimer() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.flushTimer = Timer.scheduledTimer(
                withTimeInterval: self.flushInterval,
                repeats: true
            ) { [weak self] _ in
                self?.flush()
            }
        }
    }
}
