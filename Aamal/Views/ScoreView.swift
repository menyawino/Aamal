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
        taskCompletionSeries(days: selectedRange.days)
    }

    private var weeklyCompletionRate: Double {
        taskCompletionRate(days: ChartRange.week.days)
    }

    private var monthlyCompletionRate: Double {
        taskCompletionRate(days: ChartRange.month.days)
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
        let score = (weeklyCompletionRate * 0.45) + (streakFactor * 0.35) + (badgeFactor * 0.20)
        return Int((score * 100).rounded())
    }

    private var nextStreakMilestone: Int {
        [3, 7, 14, 30, 60].first(where: { $0 > store.streak }) ?? (store.streak + 30)
    }

    private var nextBadgeMilestone: Int {
        [3, 6, 10, 15].first(where: { $0 > store.badges.count }) ?? (store.badges.count + 5)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AamalTheme.screenSpacing) {
                    ScoreHeroCard(
                        store: store,
                        leagueTitle: leagueTitle,
                        momentumScore: momentumScore
                    )
                    .aamalEntrance(0)

                    ProgressChartCard(data: chartData, range: selectedRange, selectedRange: $selectedRange)
                        .aamalEntrance(1)

                    QuranProgressChartCard(store: store, range: selectedRange)
                        .aamalEntrance(2)

                    QuestMilestonesCard(
                        store: store,
                        nextStreakMilestone: nextStreakMilestone,
                        nextBadgeMilestone: nextBadgeMilestone
                    )
                    .aamalEntrance(2)

                    AnalyticsCard(
                        store: store,
                        weeklyCompletionRate: weeklyCompletionRate,
                        monthlyCompletionRate: monthlyCompletionRate,
                        averageValue: averageValue,
                        bestValue: bestValue,
                        rangeDays: selectedRange.days,
                        consistency: taskConsistencyRate(days: selectedRange.days)
                    )
                    .aamalEntrance(3)

                    ScoreComboCard(store: store)
                        .aamalEntrance(4)

                    if !store.badges.isEmpty {
                        BadgeShelfCard(badges: store.badges)
                            .aamalEntrance(5)
                    }

                    Button(action: store.refreshContextualNotifications) {
                        Text("تحديث التذكيرات الذكية")
                    }
                    .buttonStyle(AamalPrimaryButtonStyle())
                    .aamalEntrance(6)
                }
                .padding(AamalTheme.sectionSpacing)
                .padding(.bottom, AamalTheme.screenBottomInset)
            }
            .navigationTitle("التقدم")
            .navigationBarTitleDisplayMode(.inline)
            .aamalScreen()
        }
    }

    private func taskCompletionSeries(days: Int) -> [ProgressPoint] {
        guard days > 0 else { return [] }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }

            return ProgressPoint(date: date, value: store.completion(for: store.categories, on: date))
        }
    }

    private func taskCompletionRate(days: Int) -> Double {
        let series = taskCompletionSeries(days: days)
        guard !series.isEmpty else { return 0 }
        let total = series.map(\.value).reduce(0, +)
        return total / Double(series.count)
    }

    private func taskConsistencyRate(days: Int, minimumDailyCompletion: Double = 0.6) -> Double {
        let series = taskCompletionSeries(days: days)
        guard !series.isEmpty else { return 0 }
        let consistentDays = series.filter { $0.value >= minimumDailyCompletion }.count
        return Double(consistentDays) / Double(series.count)
    }
}

private struct ScoreHeroCard: View {
    @ObservedObject var store: TaskStore
    let leagueTitle: String
    let momentumScore: Int

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            HStack(alignment: .top, spacing: 12) {
                AamalSectionHeader(
                    title: leagueTitle,
                    subtitle: "المستوى \(store.level) • \(store.totalXP) نقطة خبرة",
                    tint: AamalTheme.gold,
                    systemImage: "trophy.fill"
                )

                AamalStatPill(
                    title: "مؤشر الزخم",
                    value: "\(momentumScore)",
                    tint: AamalTheme.gold,
                    alignment: .center
                )
                .frame(maxWidth: 118)
            }

            ProgressView(value: store.levelProgress)
                .tint(AamalTheme.gold)

            HStack(spacing: 10) {
                AamalStatPill(title: "إلى المستوى التالي", value: "\(store.xpToNextLevel) XP", tint: AamalTheme.gold)
                AamalStatPill(title: "الأوسمة", value: "\(store.badges.count)", tint: AamalTheme.emerald)
            }
        }
        .aamalCardSolid()
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

private struct QuranProgressChartCard: View {
    @ObservedObject var store: TaskStore
    let range: ChartRange

    private var data: [ProgressPoint] {
        store.quranCompletionSeries(days: range.days)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("منحنى مراجعة القرآن")
                    .font(.headline)
                Spacer()
                if let last = data.last {
                    Text("\(Int((last.value * 100).rounded()))٪")
                        .font(.subheadline)
                        .foregroundColor(AamalTheme.emerald)
                }
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
                            colors: [AamalTheme.gold.opacity(0.35), AamalTheme.gold.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(AamalTheme.gold)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    PointMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(AamalTheme.emerald)
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
    let weeklyCompletionRate: Double
    let monthlyCompletionRate: Double
    let averageValue: Double
    let bestValue: Double
    let rangeDays: Int
    let consistency: Double

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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("تحليلات الإنجاز")
                .font(.headline)

            HStack {
                metricView(title: "آخر 7 أيام", value: weeklyCompletionRate)
                metricView(title: "آخر 30 يوم", value: monthlyCompletionRate)
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
