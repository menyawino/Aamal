//
//  ContentView.swift
//  Aamal
//
//  Created by Omar Ahmed on 20/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = TaskStore()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            GamifiedHomeView(store: store, selectedTab: $selectedTab)
                .tabItem {
                    Label("الرئيسية", systemImage: "sparkles")
                }
                .tag(0)

            DailyTasksView(store: store)
                .tabItem {
                    Label("أعمال اليوم", systemImage: "checklist")
                }
                .tag(1)

            ScoreView(store: store)
                .tabItem {
                    Label("التقدم", systemImage: "chart.bar.fill")
                }
                .tag(2)

            CompensationTrackerView(store: store)
                .tabItem {
                    Label("القضاء", systemImage: "clock.badge.checkmark")
                }
                .tag(3)

            QuranRevisionView(store: store)
                .tabItem {
                    Label("المراجعة", systemImage: "book.fill")
                }
                .tag(4)

            QiyamView(store: store)
                .tabItem {
                    Label("قيام الليل", systemImage: "moon.stars.fill")
                }
                .tag(5)
        }
        .tint(AamalTheme.emerald)
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

#Preview {
    ContentView()
}
