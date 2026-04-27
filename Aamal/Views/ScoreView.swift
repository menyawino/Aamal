import SwiftUI
import Charts

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

    private var leagueTitle: String {
        switch store.level {
        case 15...: return "أسطورة الثبات"
        case 10...: return "قائد الإنجاز"
        case 6...: return "فارس الورد"
        case 3...: return "صاعد بثبات"
        default: return "مبتدئ الرحلة"
        }
    }

    private var momentumScore: Int {
        let streakFactor = min(Double(store.streak) / 14, 1)
        let badgeFactor = min(Double(store.badges.count) / 8, 1)
        let score = (store.weeklyCompletionRate * 0.45) + (streakFactor * 0.35) + (badgeFactor * 0.20)
        return Int((score * 100).rounded())
    }

    private var nextStreakMilestone: Int {
        [3, 7, 14, 30, 60].first(where: { $0 > store.streak }) ?? (store.streak + 30)
    }

    private var nextBadgeMilestone: Int {
        [3, 6, 10, 15].first(where: { $0 > store.badges.count }) ?? (store.badges.count + 5)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ScoreHeroCard(
                    store: store,
                    leagueTitle: leagueTitle,
                    momentumScore: momentumScore
                )

                ProgressChartCard(data: chartData, range: selectedRange, selectedRange: $selectedRange)

                QuestMilestonesCard(
                    store: store,
                    nextStreakMilestone: nextStreakMilestone,
                    nextBadgeMilestone: nextBadgeMilestone
                )

                AnalyticsCard(
                    store: store,
                    averageValue: averageValue,
                    bestValue: bestValue,
                    rangeDays: selectedRange.days
                )

                ScoreComboCard(store: store)

                if !store.badges.isEmpty {
                    BadgeShelfCard(badges: store.badges)
                }

                Button(action: store.refreshContextualNotifications) {
                    Text("تحديث التذكيرات الذكية")
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
}

private struct ScoreHeroCard: View {
    @ObservedObject var store: TaskStore
    let leagueTitle: String
    let momentumScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(leagueTitle)
                        .font(.title3.weight(.bold))
                    Text("المستوى \(store.level) • \(store.totalXP) نقطة خبرة")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("مؤشر الزخم")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(momentumScore)")
                        .font(.title2.weight(.heavy))
                        .foregroundColor(AamalTheme.gold)
                }
            }

            ProgressView(value: store.levelProgress)
                .tint(AamalTheme.gold)

            HStack(spacing: 10) {
                HeroStatPill(title: "إلى المستوى التالي", value: "\(store.xpToNextLevel) XP", tint: AamalTheme.gold)
                HeroStatPill(title: "الأوسمة", value: "\(store.badges.count)", tint: AamalTheme.emerald)
            }
        }
        .aamalCardSolid()
    }
}

private struct HeroStatPill: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(tint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuestMilestonesCard: View {
    @ObservedObject var store: TaskStore
    let nextStreakMilestone: Int
    let nextBadgeMilestone: Int

    private var streakProgress: Double {
        guard nextStreakMilestone > 0 else { return 1 }
        return min(Double(store.streak) / Double(nextStreakMilestone), 1)
    }

    private var badgeProgress: Double {
        guard nextBadgeMilestone > 0 else { return 1 }
        return min(Double(store.badges.count) / Double(nextBadgeMilestone), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("لوحة التحديات")
                .font(.headline)

            MilestoneRow(
                title: "سلسلة الإنجاز",
                subtitle: "الهدف التالي: \(nextStreakMilestone) أيام",
                valueText: "\(store.streak)/\(nextStreakMilestone)",
                progress: streakProgress,
                tint: AamalTheme.emerald
            )

            MilestoneRow(
                title: "جمع الأوسمة",
                subtitle: "الدفعة التالية عند \(nextBadgeMilestone) أوسمة",
                valueText: "\(store.badges.count)/\(nextBadgeMilestone)",
                progress: badgeProgress,
                tint: AamalTheme.gold
            )
        }
        .aamalCard()
    }
}

private struct MilestoneRow: View {
    let title: String
    let subtitle: String
    let valueText: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(valueText)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(tint)
            }

            ProgressView(value: progress)
                .tint(tint)
        }
    }
}

private struct ScoreComboCard: View {
    @ObservedObject var store: TaskStore

    private var comboLabel: String {
        switch store.streak {
        case 30...: return "احتراق ذهبي"
        case 14...: return "سلسلة نارية"
        case 7...: return "زخم ثابت"
        case 3...: return "انطلاقة قوية"
        default: return "ابدأ السلسلة"
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("كومبو الإنجاز")
                    .font(.headline)
                Text(comboLabel)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Text("\(store.streak)")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(AamalTheme.emerald)
        }
        .aamalCard()
    }
}

private struct BadgeShelfCard: View {
    let badges: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("خزانة الأوسمة")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                ForEach(badges, id: \.self) { badge in
                    HStack(spacing: 8) {
                        Image(systemName: "seal.fill")
                            .foregroundColor(AamalTheme.gold)
                        Text(badge)
                            .font(.caption)
                            .lineLimit(2)
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(AamalTheme.emerald.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .aamalCard()
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

    private var showsProgramProgress: Bool {
        store.totalCompensationDebtUnits > 0 || store.quranRevisionPlan.totalMemorizedRubs > 0
    }

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

            if showsProgramProgress {
                HStack {
                    if store.totalCompensationDebtUnits > 0 {
                        metricMini(title: "القضاء", value: store.compensationCompletionRate)
                    }

                    if store.quranRevisionPlan.totalMemorizedRubs > 0 {
                        metricMini(title: "المراجعة", value: store.quranRevisionCompletionRate)
                    }
                }
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
