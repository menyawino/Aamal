import SwiftUI

enum AamalTheme {
    static let emerald = Color(red: 0.10, green: 0.48, blue: 0.36)
    static let gold = Color(red: 0.84, green: 0.70, blue: 0.22)
    static let sand = Color(red: 0.97, green: 0.95, blue: 0.90)
    static let ink = Color(red: 0.12, green: 0.12, blue: 0.15)
    static let mint = Color(red: 0.74, green: 0.93, blue: 0.85)

    static let backgroundGradient = LinearGradient(
        colors: [sand, Color.white, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func cardBackground() -> some ShapeStyle {
        Color(.systemBackground)
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
                            .stroke(AamalTheme.gold.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
            )
    }
}

struct AamalSolidCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(AamalTheme.emerald.opacity(0.12), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 6)
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
