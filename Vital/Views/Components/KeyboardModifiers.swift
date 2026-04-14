import SwiftUI
import UIKit

// MARK: - Keyboard Dismissal Helpers
//
// Two complementary modifiers + one imperative helper. Together they fix
// the Session 26 bug where:
//   (a) users had no obvious way to dismiss the keyboard on form sheets
//   (b) swiping the keyboard down was being eaten by the sheet's
//       pull-to-dismiss gesture, destroying in-progress form state
//
// Apply BOTH `.dismissKeyboardOnDrag()` (on the ScrollView) AND
// `.keyboardToolbarDone()` (on any view that contains a TextField) for
// belt-and-suspenders coverage across forms with and without scroll
// content. The toolbar Done button also covers the chat input bar where
// there's no scroll view to drag against.

extension View {
    /// Lets the user dismiss the keyboard by dragging the scroll view
    /// downward — the Messages/Mail interaction. Critically, this catches
    /// the swipe-down gesture BEFORE the sheet's pull-to-dismiss gesture
    /// does, so the keyboard slides away cleanly without destroying the
    /// in-progress form.
    ///
    /// Apply this directly to a `ScrollView`. Safe to use on screens
    /// without text input — it's a no-op when no keyboard is showing.
    func dismissKeyboardOnDrag() -> some View {
        self.scrollDismissesKeyboard(.interactively)
    }

    /// Adds a `Done` button above the keyboard whenever a TextField in
    /// this view is focused. Tapping resigns first responder via UIKit's
    /// imperative dismiss path — works regardless of whether the field is
    /// inside a ScrollView, a NavigationStack, or a sheet.
    ///
    /// Apply once per screen (typically on the root content view). The
    /// toolbar accessory only appears when the keyboard is actually up.
    func keyboardToolbarDone() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    KeyboardHelper.dismiss()
                }
                .foregroundColor(Brand.accent)
                .fontWeight(.semibold)
            }
        }
    }
}

/// Imperative keyboard dismissal. Use when you need to dismiss the
/// keyboard from non-View code (button actions inside view models, etc.)
/// or when a SwiftUI gesture handler can't reach a `@FocusState`.
enum KeyboardHelper {
    /// Resigns first responder on whatever currently has it. Safe to call
    /// when nothing is focused — it's a no-op.
    static func dismiss() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
