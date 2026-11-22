//
//  APIClient.swift
//
//  Talks to the biblewish.com API (the same endpoints the website uses). Sign-in is a session
//  cookie kept by URLSession; writes carry the X-Requested-With header the server requires.
//

import Foundation

enum APIConfig {

    /// Production by default. Tests can point at a local server with the BW_API_BASE environment
    /// variable (the Docker stack in the website repo listens on http://localhost:8088).
    static var baseURL: URL {
        if let override = ProcessInfo.processInfo.environment["BW_API_BASE"], let url = URL(string: override) {
            return url
        }
        return URL(string: "https://biblewish.com")!
    }

    static let termsURL = URL(string: "https://biblewish.com/terms.html")!
    static let privacyURL = URL(string: "https://biblewish.com/privacy.html")!
}

enum APIError: LocalizedError {
    /// The request never completed (offline, timeout, server unreachable).
    case network(Error)
    /// The server answered with an error.
    case server(status: Int, code: String, message: String)
    case unauthorized
    case badResponse

    var errorDescription: String? {
        switch self {
        case .network: return "Couldn\u{2019}t reach BibleWish. Check your connection and try again."
        case .server(_, _, let message): return message
        case .unauthorized: return "You\u{2019}re signed out. Please sign in again."
        case .badResponse: return "BibleWish sent an unexpected answer. Please try again."
        }
    }

    /// Worth retrying later (as opposed to a request the server will never accept).
    var isTemporary: Bool {
        switch self {
        case .network: return true
        case .server(let status, _, _): return status >= 500 || status == 429
        case .unauthorized, .badResponse: return false
        }
    }
}

final class APIClient {

    static let shared = APIClient()

    private let session: URLSession

    #if DEBUG
    /// Requests the test harness wants refused, as "POST api/plans.php?action=import" (what an older
    /// server does with an endpoint it doesn't have).
    static var simulatedRefusals: Set<String> = []
    #endif

    init() {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.shared
        configuration.httpCookieAcceptPolicy = .always
        configuration.timeoutIntervalForRequest = 20
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)
    }

    private struct ErrorBody: Decodable {
        struct Detail: Decodable {
            let code: String
            let message: String
        }
        let error: Detail
    }

    /// Sends a request and returns the raw body of a successful answer.
    @discardableResult
    func send(
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        json: Any? = nil
    ) async throws -> Data {
        #if DEBUG
        let tag = "\(method) \(path)" + (query["action"].map { "?\($0)" } ?? "")
        if Self.simulatedRefusals.contains(tag) {
            throw APIError.server(status: 404, code: "not_found", message: "Simulated refusal of \(tag)")
        }
        #endif

        var components = URLComponents(url: APIConfig.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("BibleWish", forHTTPHeaderField: "X-Requested-With")
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: json)
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.badResponse }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 401 { throw APIError.unauthorized }
            if let body = try? JSONDecoder().decode(ErrorBody.self, from: data) {
                throw APIError.server(status: http.statusCode, code: body.error.code, message: body.error.message)
            }
            throw APIError.server(status: http.statusCode, code: "error", message: "The server returned an error (\(http.statusCode)).")
        }
        return data
    }

    /// Sends a request and decodes the answer (snake_case keys, ISO 8601 dates).
    func request<T: Decodable>(
        _ type: T.Type,
        _ method: String,
        _ path: String,
        query: [String: String] = [:],
        json: Any? = nil
    ) async throws -> T {
        let data = try await send(method, path, query: query, json: json)
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw APIError.badResponse
        }
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = ISO8601DateFormatter.plain.date(from: text) ?? ISO8601DateFormatter.fractional.date(from: text) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Bad date \(text)"))
        }
        return decoder
    }()

    /// Forgets the session cookie (sign-out, or the server said we're signed out).
    func clearSession() {
        let storage = HTTPCookieStorage.shared
        for cookie in storage.cookies(for: APIConfig.baseURL) ?? [] {
            storage.deleteCookie(cookie)
        }
    }
}

extension ISO8601DateFormatter {
    static let plain: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
