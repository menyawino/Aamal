import SwiftUI
import Charts
import UserNotifications

private enum ChartRange: String, CaseIterable, Identifiable {
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "7 أيام"
        case .month: return "30 يوم"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        }
    }
}

struct ScoreView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedRange: ChartRange = .week

    private var chartData: [ProgressPoint] {
        store.completionSeries(days: selectedRange.days)
    }

    private var averageValue: Double {
        guard !chartData.isEmpty else { return 0 }
        return chartData.map(\.value).reduce(0, +) / Double(chartData.count)
    }

    private var bestValue: Double {
        chartData.map(\.value).max() ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("المستوى \(store.level)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("\(store.totalXP) نقطة")
                        .foregroundColor(.secondary)
                }
                .aamalCardSolid()

                ProgressChartCard(data: chartData, range: selectedRange, selectedRange: $selectedRange)

                VStack(alignment: .leading, spacing: 8) {
                    Text("التقدم نحو المستوى التالي")
                        .font(.headline)
                    ProgressView(value: store.levelProgress)
                        .tint(AamalTheme.gold)
                    Text("تبقى \(store.xpToNextLevel) نقطة")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .aamalCard()

                AnalyticsCard(
                    store: store,
                    averageValue: averageValue,
                    bestValue: bestValue,
                    rangeDays: selectedRange.days
                )

                VStack(spacing: 6) {
                    Text("سلسلة الإنجاز")
                        .font(.headline)
                    Text("\(store.streak) أيام")
                        .font(.title3)
                        .foregroundColor(AamalTheme.emerald)
                }
                .aamalCard()

                if !store.badges.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("الأوسمة")
                            .font(.headline)
                        ForEach(store.badges, id: \.self) { badge in
                            Text(badge)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(AamalTheme.emerald.opacity(0.12))
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aamalCard()
                }

                Button(action: scheduleNotification) {
                    Text("تفعيل التذكيرات")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(AamalTheme.emerald)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
        }
        .background(AamalTheme.backgroundGradient.ignoresSafeArea())
        .navigationTitle("التقدم")
    }

    private func scheduleNotification() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "حافظ على سلسلة الإنجاز"
            content.body = "لا تنسَ إكمال مهامك اليوم."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
            let request = UNNotificationRequest(identifier: "taskReminder", content: content, trigger: trigger)
            center.add(request, withCompletionHandler: nil)
        }
    }
}

private struct ProgressChartCard: View {
    let data: [ProgressPoint]
    let range: ChartRange
    @Binding var selectedRange: ChartRange

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("منحنى الإنجاز")
                    .font(.headline)
                Spacer()
                Picker("الفترة", selection: $selectedRange) {
                    ForEach(ChartRange.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 170)
            }

            if data.isEmpty {
                Text("لا توجد بيانات كافية للرسم البياني")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Chart(data) { point in
                    AreaMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [AamalTheme.emerald.opacity(0.35), AamalTheme.emerald.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(AamalTheme.emerald)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(AamalTheme.gold)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                    }
                }
                .frame(height: 210)
            }
        }
        .aamalCard()
    }
}

private struct AnalyticsCard: View {
    @ObservedObject var store: TaskStore
    let averageValue: Double
    let bestValue: Double
    let rangeDays: Int

    private var missedTasks: [TaskMissInsight] {
        store.mostMissedTasks(days: rangeDays, limit: 4)
    }

    private var bestCategories: [CategoryCompletionInsight] {
        store.categoryCompletionInsights(days: rangeDays, limit: 3)
    }

    private var weakestDay: WeekdayCompletionInsight? {
        store.weakestWeekdayInsight(days: rangeDays)
    }

    private var strongestDay: WeekdayCompletionInsight? {
        store.strongestWeekdayInsight(days: rangeDays)
    }

    private var consistency: Double {
        store.consistencyRate(days: rangeDays)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("تحليلات الإنجاز")
                .font(.headline)

            HStack {
                metricView(title: "آخر 7 أيام", value: store.weeklyCompletionRate)
                metricView(title: "آخر 30 يوم", value: store.monthlyCompletionRate)
            }

            HStack {
                metricMini(title: "المتوسط", value: averageValue)
                metricMini(title: "أفضل يوم", value: bestValue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("الثبات خلال الفترة")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView(value: consistency)
                    .tint(AamalTheme.gold)
                Text("\(Int(consistency * 100))٪ من الأيام حققت فيها 60٪ إنجاز أو أكثر")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !bestCategories.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("أقوى التصنيفات")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(bestCategories) { insight in
                        HStack {
                            Text(insight.categoryName)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int(insight.completionRate * 100))٪")
                                .font(.caption)
                                .foregroundColor(AamalTheme.emerald)
                        }
                    }
                }
                .padding(.top, 4)
            }

            if let strongestDay, let weakestDay {
                HStack {
                    insightMini(title: "أفضل يوم", detail: strongestDay.localizedName, value: strongestDay.completionRate)
                    insightMini(title: "أضعف يوم", detail: weakestDay.localizedName, value: weakestDay.completionRate)
                }
            }

            if !missedTasks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("مهام غالبًا تفوتك")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(missedTasks) { insight in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(insight.taskName)
                                    .font(.caption)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(Int(insight.completionRate * 100))٪")
                                    .font(.caption)
                                    .foregroundColor(AamalTheme.ink)
                            }
                            Text("فُوّتت \(insight.missedCount) من \(insight.opportunities)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(.top, 2)
            }
        }
        .aamalCard()
    }

    private func metricView(title: String, value: Double) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("\(Int(value * 100))٪")
                .font(.title3)
                .foregroundColor(AamalTheme.ink)
            ProgressView(value: value)
                .tint(AamalTheme.emerald)
        }
        .frame(maxWidth: .infinity)
    }

    private func metricMini(title: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("\(Int(value * 100))٪")
                .font(.subheadline)
                .foregroundColor(AamalTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AamalTheme.cardBackground())
        )
    }

    private func insightMini(title: String, detail: String, value: Double) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(detail)
                .font(.subheadline)
                .foregroundColor(AamalTheme.ink)
            Text("\(Int(value * 100))٪")
                .font(.caption2)
                .foregroundColor(AamalTheme.emerald)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AamalTheme.cardBackground())
        )
    }
}
