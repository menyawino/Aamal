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

            PrayerTimesTabView(store: store)
                .tabItem {
                    Label("أوقات الصلاة", systemImage: "moon.stars.fill")
                }

            DailyTasksView(store: store)
                .tabItem {
                    Label("أعمال اليوم", systemImage: "checklist")
                }

            RamadanView(store: store)
                .tabItem {
                    Label("رمضان", systemImage: "moonphase.waxing.crescent")
                }

            ScoreView(store: store)
                .tabItem {
                    Label("التقدم", systemImage: "chart.bar.fill")
                }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .environment(\.locale, Locale(identifier: "ar"))
    }
}

#Preview {
    ContentView()
}
