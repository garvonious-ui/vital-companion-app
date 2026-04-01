import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    var buttonTitle: String? = nil
    var buttonAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Brand.textMuted)

            Text(title)
                .font(.headline)
                .foregroundColor(Brand.textSecondary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Brand.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Text(buttonTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(Brand.textPrimary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Brand.accent)
                        .cornerRadius(10)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}
