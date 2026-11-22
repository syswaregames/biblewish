//
//  SendVerseView.swift
//
//  "Send to someone", like the website's send window: a name, a message, a background, and
//  optionally an email (a member gets it in their notifications too). The server makes a private
//  link (biblewish.com/v/<token>) to send by WhatsApp, Messages or anything else. Needs an account.
//

import SwiftUI

struct SendVerseView: View {

    let translation: String
    let bookIndex: Int
    let chapter: Int
    let range: ClosedRange<Int>
    let reference: String
    let text: String

    @EnvironmentObject private var auth: AuthStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.palette) private var palette

    @State private var toName = ""
    @State private var message = ""
    @State private var toEmail = ""
    @State private var fromName = ""
    @State private var style: VerseCardStyle = .sunset
    @State private var busy = false
    @State private var errorMessage: String?
    @State private var sentLink: String?
    @State private var showSignIn = false
    @State private var copied = false

    private struct Sent: Decodable { let url: String }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    preview
                    if let sentLink {
                        sent(sentLink)
                    } else if !auth.isSignedIn {
                        signInPrompt
                    } else {
                        form
                    }
                }
                .padding(16)
                .readableWidth(560)
            }
            .themedScreen()
            .navigationTitle(sentLink == nil ? "Send this verse" : "Your verse is ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(sentLink == nil ? "Cancel" : "Done") { dismiss() } }
            }
            .sheet(isPresented: $showSignIn) { SignInView() }
            .onAppear { if fromName.isEmpty { fromName = auth.user?.displayName ?? "" } }
        }
        .presentationDetents([.large])
    }

    private var preview: some View {
        Text("\u{201C}\(text.count > 220 ? String(text.prefix(220)).trimmingCharacters(in: .whitespaces) + "\u{2026}" : text)\u{201D} \u{2014} \(reference)")
            .font(.system(.callout, design: .serif))
            .italic()
            .foregroundStyle(palette.inkSoft)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .themedCard()
    }

    private var signInPrompt: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sending a verse needs a BibleWish account, so you get a notification when it is opened and answered. It is free and has no password: we email you a code.")
                .font(.subheadline)
                .foregroundStyle(palette.inkSoft)
            Button { showSignIn = true } label: {
                Text("Sign in").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(palette.gold))
                    .foregroundStyle(palette.panel)
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 16) {
            field("To", hint: "Their first name, shown on the verse.") {
                TextField("e.g. Ana", text: $toName)
                    .textContentType(.givenName)
                    .onChange(of: toName) { if toName.count > SendVerse.nameLimit { toName = String(toName.prefix(SendVerse.nameLimit)) } }
            }
            field("Your message") {
                TextField("Thinking of you today\u{2026}", text: $message, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: message) { if message.count > SendVerse.messageLimit { message = String(message.prefix(SendVerse.messageLimit)) } }
            }
            VStack(alignment: .leading, spacing: 6) {
                label("Background")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(VerseCardStyle.allCases) { option in
                            Button { style = option } label: {
                                Text(option.title)
                                    .font(.footnote.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(style == option ? palette.gold : palette.surface))
                                    .overlay(Capsule().stroke(palette.goldLine))
                                    .foregroundStyle(style == option ? palette.panel : palette.ink)
                            }
                            .accessibilityAddTraits(style == option ? .isSelected : [])
                        }
                    }
                }
            }
            field("Their email", hint: "Optional. If they have a BibleWish account they also get it in their notifications. We never show you whether they do.") {
                TextField("ana@example.com", text: $toEmail)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            field("From") {
                TextField("Your name", text: $fromName)
                    .textContentType(.name)
                    .onChange(of: fromName) { if fromName.count > SendVerse.nameLimit { fromName = String(fromName.prefix(SendVerse.nameLimit)) } }
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(palette.roseInk).accessibilityAddTraits(.updatesFrequently)
            }

            Button { Task { await send() } } label: {
                HStack {
                    if busy { ProgressView().tint(palette.panel) }
                    Text("Create my verse link")
                }
                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12).fill(palette.gold))
                .foregroundStyle(palette.panel)
            }
            .disabled(busy)
        }
    }

    private func sent(_ link: String) -> some View {
        let name = toName.trimmingCharacters(in: .whitespaces)
        let who = name.isEmpty ? "them" : name
        let line = SendVerse.shareLine(toName: toName, reference: reference)
        return VStack(alignment: .leading, spacing: 14) {
            Text(SendVerse.looksLikeEmail(toEmail)
                 ? "If \(who) uses BibleWish with that email, it is already in their notifications. You can also send the link:"
                 : "Send \(who) the link. You will get a notification on biblewish.com when it is opened and answered.")
                .font(.subheadline)
                .foregroundStyle(palette.inkSoft)

            Text(link)
                .font(.callout.monospaced())
                .foregroundStyle(palette.ink)
                .textSelection(.enabled)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .themedCard()

            if let whatsApp = SendVerse.whatsAppURL(line: line, link: link) {
                Link(destination: whatsApp) {
                    Label("Send on WhatsApp", systemImage: "paperplane.fill")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 12).fill(palette.gold))
                        .foregroundStyle(palette.panel)
                }
            }
            ShareLink(item: "\(line)\n\(link)") {
                Label("Share\u{2026}", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
            }
            Button {
                UIPasteboard.general.string = link
                copied = true
            } label: {
                Label(copied ? "Link copied" : "Copy link", systemImage: copied ? "checkmark" : "link").frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.goldLine))
            }
        }
    }

    private func label(_ title: String) -> some View {
        Text(title.uppercased()).font(.caption.weight(.semibold)).tracking(1).foregroundStyle(palette.gold)
    }

    private func field<Content: View>(_ title: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            label(title)
            content()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(palette.surface))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(palette.goldLine))
            if let hint { Text(hint).font(.caption).foregroundStyle(palette.inkMuted) }
        }
    }

    private func send() async {
        errorMessage = nil
        let email = toEmail.trimmingCharacters(in: .whitespaces)
        if !email.isEmpty && !SendVerse.looksLikeEmail(email) {
            errorMessage = "That email address does not look right. Leave it empty to send only the link."
            return
        }
        busy = true
        defer { busy = false }
        let body = SendVerse.payload(translation: translation, bookIndex: bookIndex, chapter: chapter, range: range, message: message, style: style.rawValue, toName: toName, toEmail: email, fromName: fromName)
        do {
            sentLink = try await APIClient.shared.request(Sent.self, "POST", "api/verses.php", json: body).url
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
