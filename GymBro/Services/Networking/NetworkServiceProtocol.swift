//
//  NetworkServiceProtocol.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Combine

/// Protocol defining network service capabilities for testability
protocol NetworkServiceProtocol: AnyObject {
    /// Performs a network request and returns the decoded response
    /// - Parameters:
    ///   - endpoint: The API endpoint to request
    ///   - responseType: The type to decode the response into
    /// - Returns: The decoded response
    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T

    /// Performs a network request without expecting a response body
    /// - Parameter endpoint: The API endpoint to request
    func request(_ endpoint: APIEndpoint) async throws

    /// Uploads data to the specified endpoint
    /// - Parameters:
    ///   - endpoint: The API endpoint for upload
    ///   - data: The data to upload
    ///   - responseType: The type to decode the response into
    /// - Returns: The decoded response
    func upload<T: Decodable>(
        _ endpoint: APIEndpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> T

    /// Uploads multipart form data
    /// - Parameters:
    ///   - endpoint: The API endpoint for upload
    ///   - multipartData: Array of multipart form data items
    ///   - responseType: The type to decode the response into
    /// - Returns: The decoded response
    func uploadMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        multipartData: [MultipartFormData],
        responseType: T.Type
    ) async throws -> T
}

// MARK: - Supporting Types

/// Represents an API endpoint with all necessary information for a request
struct APIEndpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let parameters: [String: Any]?
    let encoding: ParameterEncoding

    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        parameters: [String: Any]? = nil,
        encoding: ParameterEncoding = .url
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.parameters = parameters
        self.encoding = encoding
    }
}

/// HTTP methods supported by the network service
enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Parameter encoding types
enum ParameterEncoding {
    case url
    case json
}

/// Represents multipart form data for file uploads
struct MultipartFormData {
    let data: Data
    let name: String
    let fileName: String?
    let mimeType: String?

    init(
        data: Data,
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil
    ) {
        self.data = data
        self.name = name
        self.fileName = fileName
        self.mimeType = mimeType
    }
}

/// Network errors that can occur during requests
enum NetworkError: LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case invalidResponse
    case statusCode(Int)
    case decodingFailed(Error)
    case encodingFailed
    case noData
    case unauthorized
    case serverError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid"
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server"
        case .statusCode(let code):
            return "Server returned status code: \(code)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingFailed:
            return "Failed to encode request parameters"
        case .noData:
            return "No data received from server"
        case .unauthorized:
            return "Unauthorized access - please check your credentials"
        case .serverError(let message):
            return "Server error: \(message)"
        }
    }
}
