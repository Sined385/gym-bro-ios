//
//  NetworkServiceTests.swift
//  GymBroTests
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Testing
@testable import GymJam

@Suite("NetworkService Tests")
struct NetworkServiceTests {

    // MARK: - Test Models

    struct TestResponse: Codable, Equatable {
        let message: String
        let value: Int
    }

    // MARK: - Endpoint Building Tests

    @Test("Should build correct URL from endpoint path")
    func testURLBuilding() async throws {
        let mockService = MockNetworkService()
        mockService.mockResponse = TestResponse(message: "test", value: 42)

        let endpoint = APIEndpoint(
            path: "/test/endpoint",
            method: .get
        )

        _ = try await mockService.request(endpoint, responseType: TestResponse.self)

        #expect(mockService.lastEndpoint?.path == "/test/endpoint")
        #expect(mockService.requestCallCount == 1)
    }

    @Test("Should handle POST requests with JSON encoding")
    func testPostRequestWithJSON() async throws {
        let mockService = MockNetworkService()
        mockService.mockResponse = TestResponse(message: "created", value: 1)

        let endpoint = APIEndpoint(
            path: "/api/create",
            method: .post,
            parameters: ["key": "value"],
            encoding: .json
        )

        let response = try await mockService.request(endpoint, responseType: TestResponse.self)

        #expect(response.message == "created")
        #expect(mockService.requestCallCount == 1)
        #expect(mockService.lastEndpoint?.method == .post)
    }

    // MARK: - Error Handling Tests

    @Test("Should throw error when request fails")
    func testRequestFailure() async {
        let mockService = MockNetworkService()
        mockService.shouldFail = true
        mockService.errorToThrow = .invalidURL

        let endpoint = APIEndpoint(path: "/test", method: .get)

        await #expect(throws: NetworkError.self) {
            try await mockService.request(endpoint, responseType: TestResponse.self)
        }
    }

    @Test("Should handle decoding errors")
    func testDecodingError() async {
        let mockService = MockNetworkService()
        mockService.mockResponse = "wrong type" // Wrong type

        let endpoint = APIEndpoint(path: "/test", method: .get)

        await #expect(throws: NetworkError.self) {
            try await mockService.request(endpoint, responseType: TestResponse.self)
        }
    }

    @Test("Should handle unauthorized error")
    func testUnauthorizedError() async {
        let mockService = MockNetworkService()
        mockService.shouldFail = true
        mockService.errorToThrow = .unauthorized

        let endpoint = APIEndpoint(path: "/test", method: .get)

        do {
            _ = try await mockService.request(endpoint, responseType: TestResponse.self)
            Issue.record("Expected error to be thrown")
        } catch let error as NetworkError {
            if case .unauthorized = error {
                // Expected
            } else {
                Issue.record("Expected unauthorized error, got \(error)")
            }
        } catch {
            Issue.record("Wrong error type thrown")
        }
    }

    // MARK: - Upload Tests

    @Test("Should upload data successfully")
    func testDataUpload() async throws {
        let mockService = MockNetworkService()
        mockService.mockResponse = TestResponse(message: "uploaded", value: 200)

        let endpoint = APIEndpoint(path: "/upload", method: .post)
        let data = Data("test data".utf8)

        let response = try await mockService.upload(endpoint, data: data, responseType: TestResponse.self)

        #expect(response.message == "uploaded")
        #expect(mockService.uploadCallCount == 1)
    }

    @Test("Should upload multipart data successfully")
    func testMultipartUpload() async throws {
        let mockService = MockNetworkService()
        mockService.mockResponse = TestResponse(message: "uploaded", value: 201)

        let endpoint = APIEndpoint(path: "/upload/multipart", method: .post)
        let multipartData = [
            MultipartFormData(
                data: Data("file content".utf8),
                name: "file",
                fileName: "test.txt",
                mimeType: "text/plain"
            )
        ]

        let response = try await mockService.uploadMultipart(
            endpoint,
            multipartData: multipartData,
            responseType: TestResponse.self
        )

        #expect(response.message == "uploaded")
        #expect(mockService.uploadMultipartCallCount == 1)
    }

    // MARK: - Request Without Response Body Tests

    @Test("Should handle requests without response body")
    func testRequestWithoutResponse() async throws {
        let mockService = MockNetworkService()

        let endpoint = APIEndpoint(path: "/delete", method: .delete)

        try await mockService.request(endpoint)

        #expect(mockService.requestCallCount == 1)
    }

    // MARK: - Multiple Requests Test

    @Test("Should handle multiple sequential requests")
    func testMultipleRequests() async throws {
        let mockService = MockNetworkService()
        mockService.mockResponse = TestResponse(message: "success", value: 1)

        let endpoint1 = APIEndpoint(path: "/first", method: .get)
        let endpoint2 = APIEndpoint(path: "/second", method: .get)
        let endpoint3 = APIEndpoint(path: "/third", method: .get)

        _ = try await mockService.request(endpoint1, responseType: TestResponse.self)
        _ = try await mockService.request(endpoint2, responseType: TestResponse.self)
        _ = try await mockService.request(endpoint3, responseType: TestResponse.self)

        #expect(mockService.requestCallCount == 3)
        #expect(mockService.lastEndpoint?.path == "/third")
    }
}
