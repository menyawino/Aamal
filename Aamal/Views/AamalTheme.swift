import SwiftUI
import UIKit

enum AamalTheme {
    private static func adaptiveColor(
        light: (Double, Double, Double),
        dark: (Double, Double, Double),
        lightAlpha: Double = 1,
        darkAlpha: Double = 1
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let useDarkPalette = traits.userInterfaceStyle == .dark
            let components = useDarkPalette ? dark : light
            let alpha = useDarkPalette ? darkAlpha : lightAlpha

            return UIColor(
                red: components.0,
                green: components.1,
                blue: components.2,
                alpha: alpha
            )
        })
    }

    static let screenSpacing: CGFloat = 18
    static let sectionSpacing: CGFloat = 14
    static let contentSpacing: CGFloat = 10
    static let compactSpacing: CGFloat = 6
    static let screenBottomInset: CGFloat = 112
    static let cardPadding: CGFloat = 18
    static let cardCornerRadius: CGFloat = 20
    static let solidCardCornerRadius: CGFloat = 22

    static let emerald = adaptiveColor(light: (0.11, 0.47, 0.37), dark: (0.28, 0.67, 0.54))
    static let emeraldDeep = adaptiveColor(light: (0.05, 0.28, 0.23), dark: (0.11, 0.40, 0.32))
    static let gold = adaptiveColor(light: (0.82, 0.66, 0.18), dark: (0.90, 0.78, 0.36))
    static let sand = adaptiveColor(light: (0.97, 0.94, 0.87), dark: (0.13, 0.14, 0.16))
    static let clay = adaptiveColor(light: (0.76, 0.65, 0.53), dark: (0.48, 0.40, 0.28))
    static let ink = Color(.label)
    static let softInk = Color(.secondaryLabel)
    static let backgroundBase = adaptiveColor(light: (0.99, 0.98, 0.96), dark: (0.05, 0.07, 0.10))
    static let backgroundRaised = adaptiveColor(light: (0.96, 0.95, 0.92), dark: (0.09, 0.11, 0.14))
    static let surface = adaptiveColor(light: (1.00, 1.00, 0.99), dark: (0.11, 0.13, 0.16))
    static let surfaceRaised = adaptiveColor(light: (0.97, 0.96, 0.93), dark: (0.15, 0.17, 0.20))
    static let mint = adaptiveColor(light: (0.73, 0.91, 0.83), dark: (0.16, 0.28, 0.24))
    static let sky = adaptiveColor(light: (0.82, 0.89, 0.87), dark: (0.16, 0.20, 0.23))
    static let shadow = adaptiveColor(light: (0, 0, 0), dark: (0, 0, 0), lightAlpha: 0.09, darkAlpha: 0.20)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                backgroundBase,
                sky.opacity(0.18),
                backgroundRaised,
                mint.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var chromeGradient: LinearGradient {
        LinearGradient(
            colors: [
                surfaceRaised.opacity(0.98),
                backgroundRaised,
                sky.opacity(0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func actionGradient(tint: Color = emerald) -> LinearGradient {
        LinearGradient(
            colors: [
                tint,
                tint == gold ? clay.opacity(0.92) : emeraldDeep
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func cardBackground() -> some ShapeStyle {
        LinearGradient(
            colors: [
                surface,
                surfaceRaised,
                mint.opacity(0.10)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func solidCardBackground() -> some ShapeStyle {
        LinearGradient(
            colors: [
                surfaceRaised,
                surface,
                sky.opacity(0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func tonalBackground(for tint: Color) -> some ShapeStyle {
        LinearGradient(
            colors: [
                surfaceRaised,
                tint.opacity(0.16),
                backgroundRaised
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum AamalMotion {
    static let screenEntrance = Animation.spring(response: 0.5, dampingFraction: 0.88)
    static let banner = Animation.spring(response: 0.34, dampingFraction: 0.84)
    static let cardState = Animation.easeInOut(duration: 0.22)
}

enum AamalTransition {
    static var screenEntry: AnyTransition {
        .offset(y: 18).combined(with: .opacity)
    }

    static var banner: AnyTransition {
        .move(edge: .bottom).combined(with: .opacity)
    }

    static var cardState: AnyTransition {
        .scale(scale: 0.97).combined(with: .opacity)
    }
}

enum AamalStatPillLayout {
    case stacked
    case compact
}

enum AamalStatPillAlignment {
    case leading
    case center
}

struct AamalSearchField: View {
    @Binding var text: String
    let prompt: String
    var tint: Color = AamalTheme.emerald

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(tint)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
    }
}

struct AamalSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var tint: Color = AamalTheme.emerald
    var systemImage: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(tint)
                    .frame(width: 28, height: 28)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(AamalTheme.ink)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)
        }
    }
}

struct AamalStatPill: View {
    let title: String
    let value: String
    var tint: Color = AamalTheme.emerald
    var layout: AamalStatPillLayout = .stacked
    var alignment: AamalStatPillAlignment = .leading
    var showsIndicator: Bool = false

    private var stackAlignment: HorizontalAlignment {
        alignment == .center ? .center : .leading
    }

    private var frameAlignment: Alignment {
        alignment == .center ? .center : .leading
    }

    var body: some View {
        Group {
            switch layout {
            case .stacked:
                VStack(alignment: stackAlignment, spacing: AamalTheme.compactSpacing) {
                    Text(value)
                        .font(.headline.weight(.semibold))
                        .foregroundColor(AamalTheme.ink)

                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

            case .compact:
                HStack(spacing: 8) {
                    if showsIndicator {
                        Circle()
                            .fill(tint)
                            .frame(width: 8, height: 8)
                    }

                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer(minLength: 6)

                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AamalTheme.ink)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(AamalTheme.tonalBackground(for: tint))
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(tint.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct AamalEntranceModifier: ViewModifier {
    let index: Int

    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 18)
            .scaleEffect(isVisible ? 1 : 0.985)
            .animation(AamalMotion.screenEntrance.delay(Double(index) * 0.05), value: isVisible)
            .onAppear {
                guard !isVisible else { return }
                isVisible = true
            }
    }
}

struct AamalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AamalTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AamalTheme.cardCornerRadius)
                    .fill(AamalTheme.cardBackground())
                    .overlay(
                        RoundedRectangle(cornerRadius: AamalTheme.cardCornerRadius)
                            .stroke(AamalTheme.gold.opacity(0.16), lineWidth: 1)
                    )
                    .shadow(color: AamalTheme.shadow, radius: 12, x: 0, y: 7)
            )
    }
}

struct AamalSolidCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AamalTheme.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AamalTheme.solidCardCornerRadius)
                    .fill(AamalTheme.solidCardBackground())
                    .overlay(
                        RoundedRectangle(cornerRadius: AamalTheme.solidCardCornerRadius)
                            .stroke(AamalTheme.emerald.opacity(0.14), lineWidth: 1)
                    )
                    .shadow(color: AamalTheme.shadow.opacity(1.1), radius: 16, x: 0, y: 9)
            )
    }
}

struct AamalScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(AamalTheme.emerald)
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AamalTheme.chromeGradient, for: .navigationBar)
    }
}

struct AamalFormModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(AamalTheme.emerald)
            .scrollContentBackground(.hidden)
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(AamalTheme.chromeGradient, for: .navigationBar)
    }
}

struct AamalPrimaryButtonStyle: ButtonStyle {
    var tint: Color = AamalTheme.emerald

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(AamalTheme.actionGradient(tint: tint))
                    .shadow(color: tint.opacity(0.24), radius: configuration.isPressed ? 6 : 12, x: 0, y: configuration.isPressed ? 2 : 6)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

struct AamalSecondaryButtonStyle: ButtonStyle {
    var tint: Color = AamalTheme.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundColor(tint)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(AamalTheme.tonalBackground(for: tint))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(tint.opacity(configuration.isPressed ? 0.36 : 0.22), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

struct AamalChipButtonStyle: ButtonStyle {
    var tint: Color = AamalTheme.emerald
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundColor(prominent ? .white : tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(prominent ? AnyShapeStyle(AamalTheme.actionGradient(tint: tint)) : AnyShapeStyle(AamalTheme.tonalBackground(for: tint)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(tint.opacity(prominent ? 0 : 0.22), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.96 : 1)
    }
}

extension View {
    func aamalCard() -> some View {
        modifier(AamalCardModifier())
    }

    func aamalCardSolid() -> some View {
        modifier(AamalSolidCardModifier())
    }

    func aamalScreen() -> some View {
        modifier(AamalScreenModifier())
    }

    func aamalForm() -> some View {
        modifier(AamalFormModifier())
    }

    func aamalEntrance(_ index: Int = 0) -> some View {
        modifier(AamalEntranceModifier(index: index))
    }
}
