//
//  NetworkService.swift
//  GymBro
//
//  Created by Claude Code on 2026-03-12.
//

import Foundation
import Alamofire
import Combine

/// Production implementation of NetworkServiceProtocol using Alamofire
final class NetworkService: NetworkServiceProtocol {

    // MARK: - Properties

    private let session: Session
    private let baseURL: String
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: (() async -> String?)?

    // MARK: - Initialization

    init(
        baseURL: String = Configuration.baseURL,
        session: Session = .default,
        decoder: JSONDecoder = JSONDecoder(),
        encoder: JSONEncoder = JSONEncoder(),
        tokenProvider: (() async -> String?)? = nil
    ) {
        self.baseURL = baseURL
        self.session = session
        self.decoder = decoder
        self.encoder = encoder
        self.tokenProvider = tokenProvider

        // Configure decoder for common date formats
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase

        // Configure encoder
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - NetworkServiceProtocol

    func request<T: Decodable>(
        _ endpoint: APIEndpoint,
        responseType: T.Type
    ) async throws -> T {
        let url = try buildURL(for: endpoint)
        let mergedHeaders = await buildHeaders(for: endpoint)

        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: convertMethod(endpoint.method),
                parameters: endpoint.parameters,
                encoding: convertEncoding(endpoint.encoding),
                headers: convertHeaders(mergedHeaders)
            )
            .validate()
            .responseData { [weak self] response in
                guard let self = self else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }

                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try self.decoder.decode(T.self, from: data)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: NetworkError.decodingFailed(error))
                    }

                case .failure(let error):
                    let networkError = self.handleError(error, response: response.response)
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }

    func request(_ endpoint: APIEndpoint) async throws {
        let url = try buildURL(for: endpoint)
        let mergedHeaders = await buildHeaders(for: endpoint)

        return try await withCheckedThrowingContinuation { continuation in
            session.request(
                url,
                method: convertMethod(endpoint.method),
                parameters: endpoint.parameters,
                encoding: convertEncoding(endpoint.encoding),
                headers: convertHeaders(mergedHeaders)
            )
            .validate()
            .response { [weak self] response in
                guard let self = self else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }

                if let error = response.error {
                    let networkError = self.handleError(error, response: response.response)
                    continuation.resume(throwing: networkError)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func upload<T: Decodable>(
        _ endpoint: APIEndpoint,
        data: Data,
        responseType: T.Type
    ) async throws -> T {
        let url = try buildURL(for: endpoint)

        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                data,
                to: url,
                method: convertMethod(endpoint.method),
                headers: convertHeaders(endpoint.headers)
            )
            .validate()
            .responseData { [weak self] response in
                guard let self = self else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }

                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try self.decoder.decode(T.self, from: data)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: NetworkError.decodingFailed(error))
                    }

                case .failure(let error):
                    let networkError = self.handleError(error, response: response.response)
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }

    func uploadMultipart<T: Decodable>(
        _ endpoint: APIEndpoint,
        multipartData: [MultipartFormData],
        responseType: T.Type
    ) async throws -> T {
        let url = try buildURL(for: endpoint)

        return try await withCheckedThrowingContinuation { continuation in
            session.upload(
                multipartFormData: { formData in
                    for item in multipartData {
                        if let fileName = item.fileName, let mimeType = item.mimeType {
                            formData.append(
                                item.data,
                                withName: item.name,
                                fileName: fileName,
                                mimeType: mimeType
                            )
                        } else {
                            formData.append(item.data, withName: item.name)
                        }
                    }
                },
                to: url,
                method: convertMethod(endpoint.method),
                headers: convertHeaders(endpoint.headers)
            )
            .validate()
            .responseData { [weak self] response in
                guard let self = self else {
                    continuation.resume(throwing: NetworkError.invalidResponse)
                    return
                }

                switch response.result {
                case .success(let data):
                    do {
                        let decoded = try self.decoder.decode(T.self, from: data)
                        continuation.resume(returning: decoded)
                    } catch {
                        continuation.resume(throwing: NetworkError.decodingFailed(error))
                    }

                case .failure(let error):
                    let networkError = self.handleError(error, response: response.response)
                    continuation.resume(throwing: networkError)
                }
            }
        }
    }

    // MARK: - Private Helpers

    private func buildHeaders(for endpoint: APIEndpoint) async -> [String: String]? {
        var headers = endpoint.headers ?? [:]
        if let provider = tokenProvider, let token = await provider() {
            headers["Authorization"] = "Bearer \(token)"
        }
        return headers.isEmpty ? nil : headers
    }

    private func buildURL(for endpoint: APIEndpoint) throws -> String {
        guard !endpoint.path.isEmpty else {
            throw NetworkError.invalidURL
        }

        // If path is already a full URL, use it directly
        if endpoint.path.hasPrefix("http://") || endpoint.path.hasPrefix("https://") {
            return endpoint.path
        }

        // Otherwise, combine with base URL
        let path = endpoint.path.hasPrefix("/") ? endpoint.path : "/\(endpoint.path)"
        return baseURL + path
    }

    private func convertMethod(_ method: HTTPMethod) -> Alamofire.HTTPMethod {
        switch method {
        case .get: return .get
        case .post: return .post
        case .put: return .put
        case .patch: return .patch
        case .delete: return .delete
        }
    }

    private func convertEncoding(_ encoding: ParameterEncoding) -> Alamofire.ParameterEncoding {
        switch encoding {
        case .url: return URLEncoding.default
        case .json: return JSONEncoding.default
        }
    }

    private func convertHeaders(_ headers: [String: String]?) -> HTTPHeaders? {
        guard let headers = headers else { return nil }
        return HTTPHeaders(headers)
    }

    private func handleError(_ error: AFError, response: HTTPURLResponse?) -> NetworkError {
        if let statusCode = response?.statusCode {
            switch statusCode {
            case 401:
                return .unauthorized
            case 400..<500:
                return .statusCode(statusCode)
            case 500..<600:
                return .serverError("Server error with status code: \(statusCode)")
            default:
                return .statusCode(statusCode)
            }
        }

        return .requestFailed(error)
    }
}

// MARK: - Configuration

extension NetworkService {
    enum Configuration {
        /// Base URL for API requests — resolved from xcconfig via Info.plist
        static var baseURL: String {
            AppEnvironment.current.apiBaseURL
        }
    }
}
