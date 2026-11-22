//
//  AccountView.swift
//
//  The signed-in account: who you are, what is stored, and the two things Apple requires every
//  account to offer: deleting it and getting your data out.
//

import SwiftUI

struct AccountView: View {

    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var confirmSignOut = false
    @State private var showDelete = false
    @State private var deleteText = ""
    @State private var exportURL: URL?
    @State private var exportMessage: String?
    @State private var exporting = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(auth.user?.displayName ?? "BibleWish member")
                        .font(.system(.headline, design: .serif))
                    Text(auth.user?.email ?? "")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkMuted)
                }
            }
            .themedRows()

            Section(footer: Text("Everything BibleWish keeps for your account, as a file you can save.")) {
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share my data file", systemImage: "square.and.arrow.up")
                    }
                } else {
                    Button {
                        Task { await export() }
                    } label: {
                        Label(exporting ? "Preparing\u{2026}" : "Export my data", systemImage: "arrow.down.doc")
                    }
                    .disabled(exporting)
                }
                if let exportMessage {
                    Text(exportMessage).font(.caption).foregroundStyle(palette.roseInk)
                }
            }
            .themedRows()

            Section {
                Button {
                    confirmSignOut = true
                } label: {
                    Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } footer: {
                Text("Signing out keeps everything already on this device.")
            }
            .themedRows()

            Section(footer: Text("Deletes your account and everything stored on biblewish.com. What is on this device stays.")) {
                Button(role: .destructive) {
                    deleteText = ""
                    showDelete = true
                } label: {
                    Label("Delete account", systemImage: "trash")
                }
            }
            .themedRows()
        }
        .themedList()
        .navigationTitle("Account")
        .confirmationDialog("Sign out of BibleWish?", isPresented: $confirmSignOut, titleVisibility: .visible) {
            Button("Sign out", role: .destructive) {
                Task { await auth.signOut(); dismiss() }
            }
        }
        .alert("Delete your account?", isPresented: $showDelete) {
            TextField("Type DELETE", text: $deleteText)
                .textInputAutocapitalization(.characters)
            Button("Delete forever", role: .destructive) {
                guard deleteText == "DELETE" else { return }
                Task { if await auth.deleteAccount() { dismiss() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes your account and everything stored on biblewish.com, including notes and prayers. Type DELETE to confirm.")
        }
    }

    private func export() async {
        exporting = true
        exportMessage = nil
        defer { exporting = false }
        do {
            let data = try await APIClient.shared.send("GET", "api/account.php", query: ["action": "export"])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("BibleWish-data.json")
            try data.write(to: url, options: .atomic)
            exportURL = url
        } catch {
            exportMessage = (error as? LocalizedError)?.errorDescription ?? "Couldn\u{2019}t prepare the file."
        }
    }
}
