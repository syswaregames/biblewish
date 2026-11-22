//
//  AuthStore.swift
//
//  Whether the reader is signed in to biblewish.com. Signing in is optional: without it the app
//  works exactly as before, entirely on the device.
//

import Foundation

struct ServerUser: Codable, Equatable {
    let id: Int
    let email: String
    let displayName: String?
}

@MainActor
final class AuthStore: ObservableObject {

    @Published private(set) var user: ServerUser?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    /// Called after sign-out or account deletion so local sync bookkeeping can be reset.
    var onSignedOut: (() -> Void)?
    /// Called after the account was deleted on the server.
    var onAccountDeleted: (() -> Void)?

    private let cacheKey = "auth_cached_user_v1"
    private let api = APIClient.shared

    var isSignedIn: Bool { user != nil }

    init() {
        // The session cookie outlives launches, so remember who it belongs to for offline starts.
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(ServerUser.self, from: data) {
            user = cached
        }
    }

    private struct MeResponse: Decodable {
        let user: ServerUser?
    }

    /// Checks the session with the server. A network failure keeps the cached user.
    func restore() async {
        guard user != nil else { return }
        do {
            let response = try await api.request(MeResponse.self, "GET", "api/auth.php", query: ["action": "me"])
            if let fresh = response.user {
                setUser(fresh)
            } else {
                clearLocalSession()
            }
        } catch APIError.unauthorized {
            clearLocalSession()
        } catch {
            // Offline or server trouble: stay signed in and try again later.
        }
    }

    /// Emails a sign-in code. The first sign-in creates the account.
    func requestCode(email: String) async -> Bool {
        await perform {
            try await self.api.send("POST", "api/auth.php", query: ["action": "request-link"], json: ["email": email, "next": "/"])
        }
    }

    func verify(email: String, code: String) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            let response = try await api.request(
                MeResponse.self, "POST", "api/auth.php",
                query: ["action": "verify-code"], json: ["email": email, "code": code]
            )
            guard let signedIn = response.user else { throw APIError.badResponse }
            setUser(signedIn)
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            return false
        }
    }

    func signOut() async {
        _ = try? await api.send("POST", "api/auth.php", query: ["action": "logout"])
        clearLocalSession()
    }

    /// Deletes the account and everything stored on the server. Data on this device stays.
    func deleteAccount() async -> Bool {
        let done = await perform {
            try await self.api.send("DELETE", "api/account.php", json: ["confirm": "DELETE"])
        }
        if done {
            onAccountDeleted?()
            clearLocalSession()
        }
        return done
    }

    // MARK: - Helpers

    private func perform(_ work: @escaping () async throws -> Data) async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            _ = try await work()
            return true
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? "Something went wrong."
            return false
        }
    }

    private func setUser(_ newUser: ServerUser) {
        user = newUser
        if let data = try? JSONEncoder().encode(newUser) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    /// The server no longer knows this session (or the reader signed out).
    func clearLocalSession() {
        api.clearSession()
        user = nil
        UserDefaults.standard.removeObject(forKey: cacheKey)
        onSignedOut?()
    }
}
