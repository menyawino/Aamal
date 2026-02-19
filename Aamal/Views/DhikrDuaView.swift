import SwiftUI

struct DhikrDuaView: View {
    @ObservedObject var store: TaskStore

    private var groupedDuas: [String: [Dua]] {
        Dictionary(grouping: dailyDuas, by: { $0.category })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    DailyDuaCard(store: store)
                    DuaCollectionCard(groupedDuas: groupedDuas)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("الأذكار والأدعية")
        }
    }
}

private struct DailyDuaCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("دعاء اليوم")
                    .font(.headline)
                Spacer()
                Button("التالي") {
                    store.pickNextDailyDua()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            if let dua = store.todayDua {
                Text(dua.title)
                    .font(.subheadline)
                    .foregroundColor(AamalTheme.ink)
                Text(dua.text)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                Text(dua.source)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("لا يوجد دعاء متاح")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .aamalCardSolid()
    }
}

private struct DuaCollectionCard: View {
    let groupedDuas: [String: [Dua]]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مكتبة أدعية مختصرة")
                .font(.headline)

            ForEach(groupedDuas.keys.sorted(), id: \.self) { category in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    ForEach(groupedDuas[category] ?? []) { dua in
                        Text("• \(dua.title)")
                            .font(.caption)
                    }
                }
            }
        }
        .aamalCard()
    }
}
