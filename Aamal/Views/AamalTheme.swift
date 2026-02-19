import SwiftUI

enum AamalTheme {
    static let emerald = Color(red: 0.10, green: 0.48, blue: 0.36)
    static let gold = Color(red: 0.84, green: 0.70, blue: 0.22)
    static let sand = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let ink = Color(.label) // Dynamic text color (primary)
    static let mint = Color(red: 0.74, green: 0.93, blue: 0.85)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(.systemBackground),
                Color(.secondarySystemBackground),
                mint.opacity(0.45)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardBackground() -> some ShapeStyle {
        Color(.systemBackground)
    }

    static func solidCardBackground() -> some ShapeStyle {
        Color(.secondarySystemBackground)
    }
}

struct AamalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AamalTheme.cardBackground())
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(AamalTheme.gold.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.07), radius: 8, x: 0, y: 4)
            )
    }
}

struct AamalSolidCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(AamalTheme.solidCardBackground())
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AamalTheme.emerald.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 6)
            )
    }
}

extension View {
    func aamalCard() -> some View {
        modifier(AamalCardModifier())
    }

    func aamalCardSolid() -> some View {
        modifier(AamalSolidCardModifier())
    }
}
