//
//  NoteTextView.swift
//
//  The note editor's text box. SwiftUI's TextEditor can't tell us the selection on iOS 17, and the
//  toolbar needs it, so this is a UITextView. Edits go through the text view's own undo history.
//

import SwiftUI
import UIKit

/// Lets the toolbar act on the text view.
final class NoteEditorController: ObservableObject {

    weak var textView: UITextView?

    /// Makes an edit from the current text and selection, and applies it.
    func perform(_ make: (String, NSRange) -> NoteEditing.Edit) {
        guard let textView else { return }
        apply(make(textView.text ?? "", textView.selectedRange))
    }

    func apply(_ edit: NoteEditing.Edit) {
        guard let textView,
              let start = textView.position(from: textView.beginningOfDocument, offset: edit.range.location),
              let end = textView.position(from: start, offset: edit.range.length),
              let range = textView.textRange(from: start, to: end) else { return }

        // `replace` keeps the text view's undo history, so shaking to undo works on toolbar edits too.
        textView.replace(range, withText: edit.text)
        textView.selectedRange = edit.selection
        textView.delegate?.textViewDidChange?(textView)
    }

    func focus() {
        textView?.becomeFirstResponder()
    }
}

struct NoteTextView: UIViewRepresentable {

    @Binding var text: String
    let controller: NoteEditorController

    @Environment(\.palette) private var palette

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.backgroundColor = .clear
        view.textContainerInset = UIEdgeInsets(top: 8, left: 6, bottom: 8, right: 6)
        view.adjustsFontForContentSizeCategory = true
        view.alwaysBounceVertical = true
        view.keyboardDismissMode = .interactive
        view.autocorrectionType = .default
        view.accessibilityLabel = "Note text"
        view.text = text
        controller.textView = view
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        controller.textView = view

        // Only for changes from outside; typing already keeps the binding in step.
        if view.text != text { view.text = text }

        view.font = Self.font()
        view.textColor = UIColor(palette.ink)
        view.tintColor = UIColor(palette.gold)
        view.overrideUserInterfaceStyle = palette.colorScheme == .dark ? .dark : .light
        view.keyboardAppearance = palette.colorScheme == .dark ? .dark : .light
    }

    /// The body font in a serif design, scaling with Dynamic Type.
    private static func font() -> UIFont {
        let body = UIFont.preferredFont(forTextStyle: .body)
        let serif = body.fontDescriptor.withDesign(.serif).map { UIFont(descriptor: $0, size: 0) } ?? body
        return UIFontMetrics(forTextStyle: .body).scaledFont(for: serif)
    }

    final class Coordinator: NSObject, UITextViewDelegate {

        var parent: NoteTextView

        init(_ parent: NoteTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if parent.text != textView.text { parent.text = textView.text }
        }

        /// Return at the end of a list item starts the next item.
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard text == "\n", range.length == 0, textView.markedTextRange == nil,
                  let edit = NoteEditing.returnKey(textView.text ?? "", caret: range.location) else { return true }
            parent.controller.apply(edit)
            return false
        }
    }
}
