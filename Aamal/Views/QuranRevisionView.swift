import SwiftUI

struct QuranRevisionView: View {
    @ObservedObject var store: TaskStore
    @State private var juzCount: Int
    @State private var additionalHizb: Int
    @State private var additionalRub: Int
    @State private var dailyGoalRubs: Int
    @State private var feedbackMessage: String = ""

    init(store: TaskStore) {
        self.store = store

        let totalRubs = store.quranRevisionPlan.totalMemorizedRubs
        let juz = totalRubs / 8
        let remainder = totalRubs % 8

        _juzCount = State(initialValue: juz)
        _additionalHizb = State(initialValue: remainder / 4)
        _additionalRub = State(initialValue: remainder % 4)
        _dailyGoalRubs = State(initialValue: store.quranRevisionPlan.dailyGoalRubs)
    }

    private var totalDraftRubs: Int {
        min(240, (juzCount * 8) + (additionalHizb * 4) + additionalRub)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    QuranRevisionHeroCard(store: store)

                    if !feedbackMessage.isEmpty {
                        Text(feedbackMessage)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(AamalTheme.emerald)
                            .aamalCard()
                    }

                    QuranPlanEditorCard(
                        juzCount: $juzCount,
                        additionalHizb: $additionalHizb,
                        additionalRub: $additionalRub,
                        dailyGoalRubs: $dailyGoalRubs,
                        totalDraftRubs: totalDraftRubs,
                        saveAction: savePlan
                    )

                    QuranTodayMissionCard(
                        store: store,
                        completionAction: markTodayCompleted
                    )

                    QuranUpcomingScheduleCard(assignments: store.upcomingQuranRevisionAssignments)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("مراجعة القرآن")
        }
        .onAppear(perform: syncDraftFromStore)
    }

    private func syncDraftFromStore() {
        let totalRubs = store.quranRevisionPlan.totalMemorizedRubs
        juzCount = totalRubs / 8
        let remainder = totalRubs % 8
        additionalHizb = remainder / 4
        additionalRub = remainder % 4
        dailyGoalRubs = store.quranRevisionPlan.dailyGoalRubs
    }

    private func savePlan() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            store.configureQuranRevisionPlan(
                juzCount: juzCount,
                additionalHizb: additionalHizb,
                additionalRub: additionalRub,
                dailyGoalRubs: dailyGoalRubs
            )
            feedbackMessage = totalDraftRubs == 0
                ? "تم تصفير الخطة حتى تحدد مقدار المحفوظ."
                : "تم ضبط خطة المراجعة اليومية على \(dailyGoalRubs) أرباع."
        }
        syncDraftFromStore()
    }

    private func markTodayCompleted() {
        let didMark = store.markQuranRevisionCompleted()
        feedbackMessage = didMark
            ? "أُنجز ورد اليوم وتم احتساب نقاط المراجعة."
            : "ورد اليوم مسجل مسبقًا أو أن الخطة غير مهيأة بعد."
    }
}

private struct QuranRevisionHeroCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.quranRevisionRankTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(planSummary)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("سلسلة المراجعة")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.quranRevisionPlan.streak) أيام")
                        .font(.headline)
                        .foregroundColor(AamalTheme.emerald)
                }
            }

            ProgressView(value: store.quranRevisionCompletionRate)
                .tint(AamalTheme.gold)

            HStack {
                QuranMetricPill(title: "المحفوظ", value: memorizedSummary)
                QuranMetricPill(title: "هدفك اليومي", value: "\(store.quranRevisionPlan.dailyGoalRubs) ربع")
                QuranMetricPill(title: "الدورة الحالية", value: "\(Int(store.quranRevisionCompletionRate * 100))٪")
            }
        }
        .aamalCard()
    }

    private var memorizedSummary: String {
        describe(totalRubs: store.quranRevisionPlan.totalMemorizedRubs)
    }

    private var planSummary: String {
        if store.quranRevisionPlan.totalMemorizedRubs == 0 {
            return "حدد مقدار المحفوظ أولًا ليظهر الورد بدقة."
        }
        return "تدور الخطة على محفوظك بالكامل وتوزعه يوميًا بشكل ثابت."
    }

    private func describe(totalRubs: Int) -> String {
        guard totalRubs > 0 else { return "غير محدد" }
        let juz = totalRubs / 8
        let remainder = totalRubs % 8
        let hizb = remainder / 4
        let rub = remainder % 4

        var parts: [String] = []
        if juz > 0 { parts.append("\(juz) جزء") }
        if hizb > 0 { parts.append("\(hizb) حزب") }
        if rub > 0 { parts.append("\(rub) ربع") }
        return parts.joined(separator: " + ")
    }
}

private struct QuranMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AamalTheme.gold.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuranPlanEditorCard: View {
    @Binding var juzCount: Int
    @Binding var additionalHizb: Int
    @Binding var additionalRub: Int
    @Binding var dailyGoalRubs: Int
    let totalDraftRubs: Int
    let saveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("إعداد خطة المراجعة")
                .font(.headline)

            Stepper(value: $juzCount, in: 0...30) {
                row(title: "الأجزاء المحفوظة", value: "\(juzCount)")
            }

            Stepper(value: $additionalHizb, in: 0...maxAdditionalHizb) {
                row(title: "الزيادة بالأحزاب", value: "\(additionalHizb)")
            }
            .disabled(juzCount == 30)

            Stepper(value: $additionalRub, in: 0...maxAdditionalRub) {
                row(title: "الزيادة بالأرباع", value: "\(additionalRub)")
            }
            .disabled(juzCount == 30 && additionalHizb == 0)

            Stepper(value: $dailyGoalRubs, in: 1...4) {
                row(title: "الورد اليومي", value: "\(dailyGoalRubs) ربع")
            }

            Text("المحفوظ الحالي: \(describe(totalRubs: totalDraftRubs))")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: saveAction) {
                Text("حفظ خطة المراجعة")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.emerald)
        }
        .onChange(of: juzCount) { _, newValue in
            if newValue == 30 {
                additionalHizb = 0
                additionalRub = 0
            }
            additionalHizb = min(additionalHizb, maxAdditionalHizb)
            additionalRub = min(additionalRub, maxAdditionalRub)
        }
        .onChange(of: additionalHizb) { _, _ in
            additionalRub = min(additionalRub, maxAdditionalRub)
        }
        .aamalCard()
    }

    private var maxAdditionalHizb: Int {
        juzCount == 30 ? 0 : 1
    }

    private var maxAdditionalRub: Int {
        if juzCount == 30 && additionalHizb == 0 {
            return 0
        }
        return 3
    }

    private func row(title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }

    private func describe(totalRubs: Int) -> String {
        guard totalRubs > 0 else { return "غير محدد بعد" }
        let juz = totalRubs / 8
        let remainder = totalRubs % 8
        let hizb = remainder / 4
        let rub = remainder % 4

        var parts: [String] = []
        if juz > 0 { parts.append("\(juz) جزء") }
        if hizb > 0 { parts.append("\(hizb) حزب") }
        if rub > 0 { parts.append("\(rub) ربع") }
        return parts.joined(separator: " + ")
    }
}

private struct QuranTodayMissionCard: View {
    @ObservedObject var store: TaskStore
    let completionAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ورد اليوم")
                .font(.headline)

            if store.todaysQuranRevision.isEmpty {
                Text("بعد تحديد مقدار المحفوظ سيظهر لك الربع أو الربعان المطلوبان يوميًا.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("راجع اليوم هذه المواضع بالترتيب:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(store.todaysQuranRevision) { rub in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rub.shortTitle)
                                .font(.headline)
                            Text(rub.detailedTitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(rub.surahSpanText)
                                .font(.caption)
                                .foregroundColor(AamalTheme.ink)
                            Text(rub.pageSpanText)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(AamalTheme.emerald.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }

                Button(action: completionAction) {
                    Text(store.isQuranRevisionCompleted() ? "ورد اليوم مكتمل" : "تسجيل إنجاز ورد اليوم")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AamalTheme.gold)
                .disabled(store.isQuranRevisionCompleted() || store.todaysQuranRevision.isEmpty)

                Text("إكمال الورد اليومي يمنحك \(store.quranRevisionPlan.dailyGoalRubs * 6) نقطة.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .aamalCard()
    }
}

private struct QuranUpcomingScheduleCard: View {
    let assignments: [QuranDailyAssignment]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("خطة الأيام القادمة")
                .font(.headline)

            if assignments.allSatisfy({ $0.rubs.isEmpty }) {
                Text("لن تظهر الخطة إلا بعد تحديد مقدار المحفوظ.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(assignments) { assignment in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(dateTitle(for: assignment.date))
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Text(assignment.rubs.map { "\($0.detailedTitle) - \($0.surahSpanText) (\($0.pageSpanText))" }.joined(separator: "، "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AamalTheme.gold.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .aamalCardSolid()
    }

    private func dateTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "EEEE d MMM"
        return formatter.string(from: date)
    }
}