//
//  MockNetworkService.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
@testable import GymBro

/// Mock implementation of NetworkServiceProtocol for testing
final class MockNetworkService: NetworkServiceProtocol {

    // MARK: - Mock Configuration

    var shouldFail = false
    var errorToThrow: NetworkError = .invalidURL
    var responseDelay: TimeInterval = 0

    // MARK: - Tracking

    private(set) var requestCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var uploadMultipartCallCount = 0
    private(set) var lastEndpoint: APIEndpoint?

    // MARK: - Mock Responses

    var mockResponse: Any?

    // MARK: - NetworkServiceProtocol

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        requestCallCount += 1
        lastEndpoint = endpoint

        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow
        }

        guard let response = mockResponse as? T else {
            throw NetworkError.decodingFailed(
                NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock response not set or type mismatch"])
            )
        }

        return response
    }

    func request(_ endpoint: APIEndpoint) async throws {
        requestCallCount += 1
        lastEndpoint = endpoint

        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow
        }
    }

    func upload<T: Decodable>(
        _ endpoint: APIEndpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> T {
        uploadCallCount += 1
        lastEndpoint = endpoint

        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow
        }

        guard let response = mockResponse as? T else {
            throw NetworkError.decodingFailed(
                NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock response not set or type mismatch"])
            )
        }

        return response
    }

    func uploadMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        multipartData: [MultipartFormData],
        responseType: T.Type
    ) async throws -> T {
        uploadMultipartCallCount += 1
        lastEndpoint = endpoint

        if responseDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(responseDelay * 1_000_000_000))
        }

        if shouldFail {
            throw errorToThrow
        }

        guard let response = mockResponse as? T else {
            throw NetworkError.decodingFailed(
                NSError(domain: "MockError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Mock response not set or type mismatch"])
            )
        }

        return response
    }

    // MARK: - Helper Methods

    func reset() {
        requestCallCount = 0
        uploadCallCount = 0
        uploadMultipartCallCount = 0
        lastEndpoint = nil
        mockResponse = nil
        shouldFail = false
        responseDelay = 0
    }
}
