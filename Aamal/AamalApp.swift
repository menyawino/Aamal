//
//  AamalApp.swift
//  Aamal
//
//  Created by Omar Ahmed on 20/01/2026.
//

import SwiftUI
import UIKit

@main
struct AamalApp: App {
    init() {
        Self.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private static func configureAppearance() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithOpaqueBackground()
        navigationAppearance.backgroundColor = UIColor(AamalTheme.sand)
        navigationAppearance.shadowColor = UIColor(AamalTheme.gold).withAlphaComponent(0.14)
        navigationAppearance.titleTextAttributes = [.foregroundColor: UIColor(AamalTheme.ink)]
        navigationAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(AamalTheme.ink)]

        UINavigationBar.appearance().standardAppearance = navigationAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navigationAppearance
        UINavigationBar.appearance().compactAppearance = navigationAppearance
        UINavigationBar.appearance().tintColor = UIColor(AamalTheme.emerald)
        UINavigationBar.appearance().prefersLargeTitles = false

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithTransparentBackground()
        tabAppearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tabAppearance.backgroundColor = UIColor(AamalTheme.surfaceRaised).withAlphaComponent(0.74)
        tabAppearance.shadowColor = UIColor(AamalTheme.softInk).withAlphaComponent(0.08)
        tabAppearance.selectionIndicatorImage = tabSelectionIndicatorImage()

        let selectedColor = UIColor(AamalTheme.emerald)
        let normalColor = UIColor(AamalTheme.softInk)
        let selectedAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: selectedColor,
            .font: UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]
        let normalAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: normalColor.withAlphaComponent(0.92),
            .font: UIFont.systemFont(ofSize: 11, weight: .medium)
        ]
        [tabAppearance.stackedLayoutAppearance, tabAppearance.inlineLayoutAppearance, tabAppearance.compactInlineLayoutAppearance].forEach { appearance in
            appearance.selected.iconColor = selectedColor
            appearance.selected.titleTextAttributes = selectedAttributes
            appearance.normal.iconColor = normalColor.withAlphaComponent(0.84)
            appearance.normal.titleTextAttributes = normalAttributes
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor
        UITabBar.appearance().isTranslucent = true
    }

    private static func tabSelectionIndicatorImage() -> UIImage {
        let size = CGSize(width: 84, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { _ in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 5, dy: 4)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: 20)
            UIColor(AamalTheme.emerald).withAlphaComponent(0.14).setFill()
            path.fill()
        }
        .resizableImage(withCapInsets: UIEdgeInsets(top: 22, left: 42, bottom: 22, right: 42), resizingMode: .stretch)
    }
}
