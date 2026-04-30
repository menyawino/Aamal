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
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(AamalTheme.sand)
        tabAppearance.shadowColor = UIColor(AamalTheme.gold).withAlphaComponent(0.10)

        let selectedColor = UIColor(AamalTheme.emerald)
        let normalColor = UIColor(AamalTheme.softInk)
        [tabAppearance.stackedLayoutAppearance, tabAppearance.inlineLayoutAppearance, tabAppearance.compactInlineLayoutAppearance].forEach { appearance in
            appearance.selected.iconColor = selectedColor
            appearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
            appearance.normal.iconColor = normalColor
            appearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        }

        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = selectedColor
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }
}
