import SwiftUI

/// A simple holding screen for a tab that isn't built yet.
struct PlaceholderScreen: View {
    var title: String
    var symbol: String
    var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .themeFont(.largeTitle)
                .foregroundStyle(Theme.fg)
                .padding(.horizontal, 22)
                .padding(.top, 58)

            Spacer()

            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(Theme.fg3)
                    .accessibilityHidden(true)
                SpecLabel(message)
            }
            .frame(maxWidth: .infinity)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }
}

#Preview {
    PlaceholderScreen(title: "Tuner", symbol: "tuningfork", message: "Coming in M4")
}
