//
//  ContentView.swift
//  Aamal
//
//  Created by Omar Ahmed on 20/01/2026.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = TaskStore()

    var body: some View {
        TabView {
            GamifiedHomeView(store: store)
                .tabItem {
                    Label("الرئيسية", systemImage: "sparkles")
                }

            DailyTasksView(store: store)
                .tabItem {
                    Label("أعمال اليوم", systemImage: "checklist")
                }

            ScoreView(store: store)
                .tabItem {
                    Label("التقدم", systemImage: "chart.bar.fill")
                }

            CompensationTrackerView(store: store)
                .tabItem {
                    Label("القضاء", systemImage: "clock.badge.checkmark")
                }

            QuranRevisionView(store: store)
                .tabItem {
                    Label("المراجعة", systemImage: "book.closed.fill")
                }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

#Preview {
    ContentView()
}
