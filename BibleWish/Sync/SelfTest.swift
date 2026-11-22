//
//  SelfTest.swift
//
//  Debug-only checks that run inside the real app against the local biblewish.com server (the
//  Docker stack in the website repo, with Mailpit catching the sign-in emails). Not in Release.
//
//  Run:  docker compose up -d   (in the website repo)
//        SIMCTL_CHILD_BW_SELFTEST=1 SIMCTL_CHILD_BW_API_BASE=http://localhost:8088 \
//          xcrun simctl launch --console <device> Sysware.BibleWish
//  Results are printed to stderr as PASS / FAIL lines, ending with SELFTEST DONE.
//

#if DEBUG
import Foundation

@MainActor
final class SelfTest {

    let auth: AuthStore

    private(set) var failures = 0

    init(auth: AuthStore) {
        self.auth = auth
    }

    // MARK: - Helpers

    private func emit(_ text: String) { fputs(text + "\n", stderr) }

    func check(_ name: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
        emit((ok ? "PASS " : "FAIL ") + name + (ok ? "" : " " + detail()))
        if !ok { failures += 1 }
    }

    private func clearMailbox() async {
        var request = URLRequest(url: URL(string: "http://localhost:8025/api/v1/messages")!)
        request.httpMethod = "DELETE"
        _ = try? await URLSession.shared.data(for: request)
    }

    private func latestMailCode() async -> String? {
        struct List: Decodable { struct Message: Decodable { let ID: String }; let messages: [Message] }
        struct Message: Decodable { let Text: String? }
        for _ in 0..<10 {
            if let (data, _) = try? await URLSession.shared.data(from: URL(string: "http://localhost:8025/api/v1/messages")!),
               let id = (try? JSONDecoder().decode(List.self, from: data))?.messages.first?.ID,
               let (body, _) = try? await URLSession.shared.data(from: URL(string: "http://localhost:8025/api/v1/message/\(id)")!),
               let text = (try? JSONDecoder().decode(Message.self, from: body))?.Text,
               let range = text.range(of: #"\b\d{6}\b"#, options: .regularExpression) {
                return String(text[range])
            }
            try? await Task.sleep(nanoseconds: 400_000_000)
        }
        return nil
    }

    /// Signs in with a fresh throwaway account on the local server.
    func signInFreshAccount(_ label: String = "apptest") async -> String? {
        let email = "\(label)\(Int(Date().timeIntervalSince1970))\(Int.random(in: 100...999))@example.test"
        await clearMailbox()
        guard await auth.requestCode(email: email), let code = await latestMailCode(),
              await auth.verify(email: email, code: code) else { return nil }
        return email
    }

    // MARK: - Run

    func run() async {
        check("base url is local", APIConfig.baseURL.absoluteString == "http://localhost:8088", APIConfig.baseURL.absoluteString)
        await runAuth()
        emit(failures == 0 ? "SELFTEST ALL PASSED" : "SELFTEST \(failures) FAILED")
        emit("SELFTEST DONE")
    }

    // MARK: - Sign-in

    private func runAuth() async {
        check("starts signed out", !auth.isSignedIn)
        let email = "apptest\(Int(Date().timeIntervalSince1970))@example.test"
        await clearMailbox()
        check("request code", await auth.requestCode(email: email), auth.errorMessage ?? "")
        let code = await latestMailCode()
        check("code arrived", code != nil)
        check("wrong code rejected", await auth.verify(email: email, code: "000000") == false && auth.errorMessage != nil)
        check("right code signs in", await auth.verify(email: email, code: code ?? "") && auth.user?.email == email, auth.errorMessage ?? "")
        let firstId = auth.user?.id
        await auth.restore()
        check("restore keeps the session", auth.isSignedIn)
        let export = try? await APIClient.shared.send("GET", "api/account.php", query: ["action": "export"])
        check("export has the email", export.flatMap { String(data: $0, encoding: .utf8) }?.contains(email) == true)
        await auth.signOut()
        check("sign out", !auth.isSignedIn)
        check("server rejects after sign out", (try? await APIClient.shared.send("GET", "api/highlights.php")) == nil)

        await clearMailbox()
        _ = await auth.requestCode(email: email)
        check("sign in again", await auth.verify(email: email, code: await latestMailCode() ?? ""))
        check("delete account", await auth.deleteAccount() && !auth.isSignedIn, auth.errorMessage ?? "")
        check("deleted session is dead", (try? await APIClient.shared.send("GET", "api/highlights.php")) == nil)

        await clearMailbox()
        _ = await auth.requestCode(email: email)
        check("same email is a new account after deleting", await auth.verify(email: email, code: await latestMailCode() ?? "") && auth.user?.id != firstId)
        await auth.signOut()
    }
}
#endif
