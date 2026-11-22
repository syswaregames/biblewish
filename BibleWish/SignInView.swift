//
//  SignInView.swift
//
//  Sign in to biblewish.com with an emailed code. Optional: the app works fully without it.
//

import SwiftUI

struct SignInView: View {

    @EnvironmentObject var auth: AuthStore
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(codeSent ? "Enter your code" : "Sign in to sync")
                        .font(.system(.title2, design: .serif, weight: .semibold))
                        .foregroundStyle(palette.ink)

                    Text(codeSent
                         ? "We emailed a 6-digit code to \(email). It works for 15 minutes."
                         : "Your notes, favorites, highlights, reading progress, plans and prayers will follow you between this app and biblewish.com. We\u{2019}ll email you a code; no password. If you don\u{2019}t have an account yet, this creates one.")
                        .font(.subheadline)
                        .foregroundStyle(palette.inkSoft)

                    if codeSent {
                        TextField("123456", text: $code)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .font(.system(.title2, design: .monospaced))
                            .padding(14)
                            .themedCard(cornerRadius: 10)
                            .onChange(of: code) {
                                code = String(code.filter(\.isNumber).prefix(6))
                            }
                    } else {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(14)
                            .themedCard(cornerRadius: 10)
                    }

                    if let message = auth.errorMessage {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(palette.roseInk)
                    }

                    Button(action: submit) {
                        HStack {
                            if auth.isBusy { ProgressView().tint(palette.gold) }
                            Text(codeSent ? "Sign in" : "Email me a code")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(palette.gold.opacity(0.22)))
                        .overlay(Capsule().stroke(palette.gold.opacity(0.7)))
                    }
                    .disabled(!canSubmit || auth.isBusy)

                    if codeSent {
                        Button("Use a different email") {
                            codeSent = false
                            code = ""
                            auth.errorMessage = nil
                        }
                        .font(.subheadline)
                    }

                    Text("By continuing you agree to the [Terms](\(APIConfig.termsURL.absoluteString)) and the [Privacy Policy](\(APIConfig.privacyURL.absoluteString)).")
                        .font(.caption)
                        .foregroundStyle(palette.inkMuted)
                }
                .padding(20)
                .readableWidth(520)
            }
            .themedScreen()
            .navigationTitle("Account")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear { auth.errorMessage = nil }
    }

    private var canSubmit: Bool {
        codeSent ? code.count == 6 : email.contains("@") && email.contains(".")
    }

    private func submit() {
        let trimmed = email.trimmingCharacters(in: .whitespaces).lowercased()
        Task {
            if codeSent {
                if await auth.verify(email: trimmed, code: code) { dismiss() }
            } else {
                email = trimmed
                if await auth.requestCode(email: trimmed) { codeSent = true }
            }
        }
    }
}
