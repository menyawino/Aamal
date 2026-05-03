import SwiftUI
import CoreLocation
import UIKit

struct GamifiedHomeView: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedTab: Int
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel: PrayerTimesViewModel

    private let contentHorizontalPadding: CGFloat = AamalTheme.sectionSpacing + 4
    private let contentTopPadding: CGFloat = AamalTheme.contentSpacing + 2
    private let contentBottomPadding: CGFloat = AamalTheme.screenBottomInset + AamalTheme.contentSpacing
    private let cardStackSpacing: CGFloat = AamalTheme.screenSpacing + 4

    init(store: TaskStore, selectedTab: Binding<Int>) {
        self.store = store
        self._selectedTab = selectedTab
        _prayerViewModel = StateObject(wrappedValue: PrayerTimesViewModel(store: store))
    }

    private var completedTodayCount: Int {
        store.allTasks.filter { store.isTaskCompleted($0, on: Date()) }.count
    }

    private var pendingTodayCount: Int {
        max(0, store.totalTaskCount - completedTodayCount)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardStackSpacing) {
                    HeroProgressCard(store: store)
                        .aamalEntrance(0)
                    HomeTodayStatusCard(
                        completedCount: completedTodayCount,
                        pendingCount: pendingTodayCount,
                        nextPrayerName: nextPrayerSlot?.arabicName
                    )
                    .aamalEntrance(1)
                    HomeQuickActionsCard(
                        refreshAction: { refreshPrayerTimes(force: true) }
                    )
                    .aamalEntrance(2)
                    TimeBoundTasksCard(store: store, nextPrayer: nextPrayerSlot)
                        .aamalEntrance(3)
                    QuickLogSection(store: store, onlyNonPrayer: true, allowedPrayer: nextPrayerSlot?.arabicName)
                        .aamalEntrance(4)

                    HomeQuranStatusCard(store: store, onTap: { selectedTab = 4 })
                        .aamalEntrance(5)

                    HomeQiyamStatusCard(store: store, onTap: { selectedTab = 5 })
                        .aamalEntrance(6)

                    ForEach(Array(store.categories.enumerated()), id: \.element.name) { index, category in
                        if category.name == "مهام الجمعة" && !isFriday() {
                            EmptyView()
                        } else if category.name == "اليومي" {
                            EmptyView()
                        } else {
                            TaskCategoryCard(category: category, store: store)
                                .aamalEntrance(index + 5)
                        }
                    }
                }
                .padding(.top, contentTopPadding)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, contentBottomPadding)
            }
            .refreshable {
                refreshPrayerTimes(force: true)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { refreshPrayerTimes(force: true) }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("تحديث")
                }
            }
            .navigationTitle("أعمال")
            .navigationBarTitleDisplayMode(.inline)
            .aamalScreen()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, location in
            guard let location else { return }
            prayerViewModel.refresh(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                fallbackCity: locationManager.city,
                fallbackCountry: locationManager.country
            )
        }
    }

    private func refreshPrayerTimes(force: Bool) {
        if let location = locationManager.location {
            prayerViewModel.refresh(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                fallbackCity: locationManager.city,
                fallbackCountry: locationManager.country,
                force: force
            )
        } else {
            locationManager.requestLocation()
        }
    }

    private var nextPrayerSlot: PrayerSlot? {
        guard let timings = prayerViewModel.timings else { return nil }
        let slots = timings.slots().sorted(by: { $0.date < $1.date })
        let now = Date()

        if let next = slots.first(where: { $0.date > now }) {
            return next
        }

        guard let first = slots.first,
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: first.date)
        else {
            return nil
        }

        return PrayerSlot(apiKey: "FajrNextDay", arabicName: "الصبح", date: tomorrow)
    }

    private func isFriday() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 6
    }

}

private struct HomeTodayStatusCard: View {
    let completedCount: Int
    let pendingCount: Int
    let nextPrayerName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            AamalSectionHeader(
                title: "ملخص سريع",
                subtitle: nextPrayerName.map { "الصلاة القادمة: \($0)" } ?? "نظرة مركزة على اليوم قبل الدخول للتفاصيل.",
                tint: AamalTheme.gold,
                systemImage: "chart.bar.doc.horizontal"
            )

            HStack(spacing: 10) {
                AamalStatPill(
                    title: "المتبقي اليوم",
                    value: "\(pendingCount)",
                    tint: AamalTheme.gold,
                    layout: .compact,
                    showsIndicator: true
                )
                AamalStatPill(
                    title: "المكتمل",
                    value: "\(completedCount)",
                    tint: AamalTheme.emerald,
                    layout: .compact,
                    showsIndicator: true
                )
            }
        }
        .aamalCard()
    }
}

private struct HomeQuickActionsCard: View {
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            AamalSectionHeader(
                title: "إجراءات سريعة",
                subtitle: "التسجيل من الصفحة الرئيسية يتم مهمة بمهمة.",
                tint: AamalTheme.emerald,
                systemImage: "bolt.circle"
            )

            Button(action: refreshAction) {
                Label("تحديث الأوقات", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AamalSecondaryButtonStyle())
        }
        .controlSize(.small)
        .aamalCard()
    }
}



private struct HeroProgressCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            AamalSectionHeader(
                title: "رحلة اليوم",
                subtitle: "المستوى \(store.level) • \(store.totalXP) نقطة",
                tint: AamalTheme.emerald,
                systemImage: "sparkles"
            )

            HStack(spacing: 10) {
                AamalStatPill(title: "سلسلة الإنجاز", value: "\(store.streak) أيام", tint: AamalTheme.emerald)
                AamalStatPill(title: "إلى المستوى التالي", value: "\(store.xpToNextLevel) نقطة", tint: AamalTheme.gold)
            }

            ProgressView(value: store.overallProgress) {
                Text("\(Int(store.overallProgress * 100))% مكتمل")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .tint(AamalTheme.emerald)

            HStack {
                Text("المستوى التالي بعد \(store.xpToNextLevel) نقطة")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                ProgressView(value: store.levelProgress)
                    .frame(maxWidth: 120)
                    .tint(AamalTheme.gold)
            }
        }
        .aamalCardSolid()
    }
}

private struct QuickLogSection: View {
    @ObservedObject var store: TaskStore
    let onlyNonPrayer: Bool
    let allowedPrayer: String?

    private var isFridayToday: Bool {
        Calendar.current.component(.weekday, from: Date()) == 6
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            AamalSectionHeader(
                title: "تسجيل سريع",
                subtitle: "أنجز بسرعة أهم المهام المتبقية اليوم.",
                tint: AamalTheme.gold,
                systemImage: "checklist"
            )

            let tasks = filteredTasks(limit: 3)
            if tasks.isEmpty {
                Text("كل المهام مسجلة. أحسنت!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(tasks) { task in
                    QuickLogRow(task: task, store: store)
                }
            }
        }
        .aamalCard()
    }

    private func filteredTasks(limit: Int) -> [Task] {
        let pending = store.allTasks.filter {
            !store.isTaskCompleted($0, on: Date()) && (isFridayToday || $0.category != "وظائف الجمعة")
        }

        if onlyNonPrayer {
            let prayerName = allowedPrayer
            return Array(pending.filter { task in
                if store.isPrayerTask(task) {
                    return task.category == prayerName
                }
                return true
            }.prefix(limit))
        }

        return Array(pending.prefix(limit))
    }
}

private struct QuickLogRow: View {
    let task: Task
    @ObservedObject var store: TaskStore

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline)
                Text(task.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text("+\(task.score) نقطة")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: {
                withAnimation(AamalMotion.cardState) {
                    _ = store.logTask(taskId: task.id, on: Date())
                }
            }) {
                Text("سجل")
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(AamalChipButtonStyle(prominent: true))
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

private struct TaskCategoryCard: View {
    let category: TaskCategory
    @ObservedObject var store: TaskStore

    private var nonPrayerSubCategories: [SubCategory] {
        category.subCategories?.filter { !$0.tasks.allSatisfy(store.isPrayerTask) } ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            AamalSectionHeader(
                title: category.name,
                subtitle: "\(Int(store.completion(for: category) * 100))٪ مكتمل حتى الآن",
                tint: AamalTheme.emerald,
                systemImage: "square.grid.2x2"
            )

            ProgressView(value: store.completion(for: category))
                .tint(AamalTheme.emerald)

            if category.name == "اليومي" {
                PrayerTaskSummaryList(store: store)

                ForEach(nonPrayerSubCategories, id: \.name) { subCategory in
                    CompactTaskList(title: subCategory.name, tasks: subCategory.tasks, store: store)
                }
            } else {
                if let subCategories = category.subCategories {
                    ForEach(subCategories, id: \.name) { subCategory in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(subCategory.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(subCategory.tasks) { task in
                                TaskRow(task: task, store: store)
                            }
                        }
                        .padding(.top, 6)
                    }
                }

                if let tasks = category.tasks {
                    ForEach(tasks) { task in
                        TaskRow(task: task, store: store)
                    }
                }
            }
        }
        .aamalCard()
    }
}

private struct TimeBoundTasksCard: View {
    @ObservedObject var store: TaskStore
    let nextPrayer: PrayerSlot?

    private var nextPrayerTasks: [Task] {
        guard let nextPrayer else { return [] }
        return store.tasks(forPrayerName: nextPrayer.arabicName)
    }

    private var pendingNextPrayerTasks: [Task] {
        nextPrayerTasks.filter { !store.isTaskCompleted($0, on: Date()) }
    }

    private var minutesUntilPrayer: Int? {
        guard let nextPrayer else { return nil }
        let distance = Int(Date().distance(to: nextPrayer.date) / 60)
        return max(0, distance)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            AamalSectionHeader(
                title: "المهام المرتبطة بالصلاة القادمة",
                subtitle: nextPrayer == nil ? "لا توجد صلاة قادمة محفوظة الآن." : "أقرب مجموعة تحتاج متابعة سريعة قبل دخول الوقت.",
                tint: AamalTheme.gold,
                systemImage: "clock.badge"
            )

            if let nextPrayer {
                HStack {
                    Text("الصلاة القادمة: \(nextPrayer.arabicName)")
                        .font(.subheadline)
                        .foregroundColor(AamalTheme.ink)
                    Spacer()
                    if let minutesUntilPrayer {
                        Text("بعد \(minutesUntilPrayer) دقيقة")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                PrayerTaskGroupCard(prayerName: nextPrayer.arabicName, tasks: nextPrayerTasks, store: store)
            } else {
                Text("لا توجد مهام صلاة حالياً")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .aamalCard()
    }
}

private struct PrayerTaskSummaryList: View {
    @ObservedObject var store: TaskStore

    private let prayerNames = ["الصبح", "الظهر", "العصر", "المغرب", "العشاء"]

    var body: some View {
        VStack(spacing: AamalTheme.contentSpacing) {
            ForEach(prayerNames, id: \.self) { prayer in
                PrayerTaskGroupCard(prayerName: prayer, tasks: store.tasks(forPrayerName: prayer), store: store)
            }
        }
        .padding(.top, 6)
    }
}

private struct PrayerTaskGroupCard: View {
    let prayerName: String
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    @State private var showAllPending = false

    private var completion: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { store.isTaskCompleted($0, on: Date()) }.count
        return Double(completed) / Double(tasks.count)
    }

    private var pendingTasks: [Task] {
        tasks.filter { !store.isTaskCompleted($0, on: Date()) }
    }

    private var visibleTasks: [Task] {
        if showAllPending {
            return pendingTasks
        }
        return Array(pendingTasks.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            HStack {
                Text(prayerName)
                    .font(.subheadline)
                    .foregroundColor(AamalTheme.ink)
                Spacer()
                Text("\(Int(completion * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: completion)
                .tint(AamalTheme.emerald)

            if pendingTasks.isEmpty {
                Text("كل مهام الصلاة مكتملة")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(visibleTasks) { task in
                    HStack {
                        Text(task.name)
                            .font(.caption)
                        Spacer()
                        Button("سجل") {
                            withAnimation(AamalMotion.cardState) {
                                _ = store.logTask(taskId: task.id, on: Date())
                            }
                        }
                        .buttonStyle(AamalChipButtonStyle(prominent: true))
                        .controlSize(.small)
                    }
                    .transition(AamalTransition.cardState)
                }

                if pendingTasks.count > 2 {
                    Button(showAllPending ? "إخفاء بعض المهام" : "عرض كل المهام المتبقية") {
                        withAnimation(AamalMotion.cardState) {
                            showAllPending.toggle()
                        }
                    }
                    .buttonStyle(AamalSecondaryButtonStyle())
                    .controlSize(.small)

                    if !showAllPending {
                        let remaining = pendingTasks.count - visibleTasks.count
                        if remaining > 0 {
                            Button(action: { showAllPending = true }) {
                                Text("+\(remaining) مهام أخرى")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.1), lineWidth: 1)
                )
        )
        .animation(AamalMotion.cardState, value: showAllPending)
        .animation(AamalMotion.cardState, value: visibleTasks.map(\.id))
    }
}

private struct CompactTaskList: View {
    let title: String
    let tasks: [Task]
    @ObservedObject var store: TaskStore

    private var completion: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { store.isTaskCompleted($0, on: Date()) }.count
        return Double(completed) / Double(tasks.count)
    }

    private var upcomingTasks: [Task] {
        Array(tasks.filter { !store.isTaskCompleted($0, on: Date()) }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(AamalTheme.ink)
                Spacer()
                Text("\(Int(completion * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: completion)
                .tint(AamalTheme.emerald)

            if upcomingTasks.isEmpty {
                Text("مكتملة بالكامل")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(upcomingTasks) { task in
                    HStack {
                        Text(task.name)
                            .font(.caption)
                        Spacer()
                        Button("سجل") {
                            withAnimation(AamalMotion.cardState) {
                                _ = store.logTask(taskId: task.id, on: Date())
                            }
                        }
                        .buttonStyle(AamalChipButtonStyle())
                        .controlSize(.small)
                    }
                    .transition(AamalTransition.cardState)
                }

                let remaining = tasks.filter { !store.isTaskCompleted($0, on: Date()) }.count - upcomingTasks.count
                if remaining > 0 {
                    Text("+\(remaining) مهام أخرى")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.1), lineWidth: 1)
                )
        )
        .animation(AamalMotion.cardState, value: upcomingTasks.map(\.id))
    }
}

private struct TaskRow: View {
    let task: Task
    @ObservedObject var store: TaskStore

    var body: some View {
        HStack(spacing: 12) {
            let isCompleted = store.isTaskCompleted(task, on: Date())
            Image(systemName: isCompleted ? "checkmark.seal.fill" : "seal")
                .foregroundColor(isCompleted ? AamalTheme.emerald : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline)
                Text("+\(task.score) نقطة")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isCompleted {
                Text("مكتمل")
                    .font(.caption)
                    .foregroundColor(AamalTheme.emerald)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(AamalTheme.emerald.opacity(0.12))
                    )

                Button(action: {
                    withAnimation(AamalMotion.cardState) {
                        _ = store.unlogTask(taskId: task.id, on: Date())
                    }
                }) {
                    Text("إلغاء التسجيل")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))
            } else {
                Button(action: {
                    withAnimation(AamalMotion.cardState) {
                        _ = store.logTask(taskId: task.id, on: Date())
                    }
                }) {
                    Text("سجل")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(AamalChipButtonStyle(prominent: true))
            }

        }
        .padding(.vertical, 4)
    }
}

private struct HomeQuranStatusCard: View {
    @ObservedObject var store: TaskStore
    let onTap: () -> Void

    private var plan: QuranAdaptiveDailyPlan {
        store.todaysAdaptiveQuranPlan
    }

    private var isCompleted: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return store.quranRevisionPlan.completedDates.contains(today)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            HStack {
                AamalSectionHeader(
                    title: "مراجعة المحفوظ",
                    subtitle: isCompleted ? "تمت مراجعة اليوم" : "خطة اليوم: \(plan.requiredRevision.count) أرباع",
                    tint: AamalTheme.emerald,
                    systemImage: "book.fill"
                )
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !plan.requiredRevision.isEmpty {
                HStack(spacing: 10) {
                    AamalStatPill(
                        title: "الأرباع المطلوبة",
                        value: "\(plan.requiredRevision.count)",
                        tint: AamalTheme.gold,
                        layout: .compact,
                        showsIndicator: true
                    )
                    AamalStatPill(
                        title: "الحالة",
                        value: isCompleted ? "مكتمل" : "مستمر",
                        tint: isCompleted ? AamalTheme.emerald : AamalTheme.gold,
                        layout: .compact,
                        showsIndicator: true
                    )
                }

                if let first = plan.requiredRevision.first {
                    Text("يبدأ اليوم بـ: \(first.rangeText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if plan.guidance.contains("حدد مقدار المحفوظ") {
                Text("لم يتم ضبط خطة المراجعة بعد.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("لا يوجد مراجعة مطلوبة اليوم.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onTap) {
                Label("فتح المراجعة", systemImage: "arrow.up.left.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AamalSecondaryButtonStyle())
            .controlSize(.small)
        }
        .aamalCard()
    }
}

private struct HomeQiyamStatusCard: View {
    @ObservedObject var store: TaskStore
    let onTap: () -> Void

    private var session: QiyamSession? {
        store.todaysQiyamSession
    }

    private var streak: Int {
        store.quranRevisionPlan.qiyamStreak
    }

    private var rank: QuranQiyamRank? {
        QuranQiyamRank.rank(for: session?.ayatCount ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            HStack {
                AamalSectionHeader(
                    title: "قيام الليل",
                    subtitle: session == nil ? "لم يُسجل قيام الليل اليوم" : "تم تسجيل \(session!.ayatCount) آية",
                    tint: AamalTheme.gold,
                    systemImage: "moon.stars.fill"
                )
                Spacer()
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 10) {
                AamalStatPill(
                    title: "السلسلة",
                    value: "\(streak) أيام",
                    tint: AamalTheme.gold,
                    layout: .compact,
                    showsIndicator: true
                )
                if let rank {
                    AamalStatPill(
                        title: "المرتبة",
                        value: rank.title,
                        tint: AamalTheme.emerald,
                        layout: .compact,
                        showsIndicator: true
                    )
                } else {
                    AamalStatPill(
                        title: "المرتبة",
                        value: "—",
                        tint: .secondary,
                        layout: .compact,
                        showsIndicator: false
                    )
                }
            }

            if let session, let range = session.rangeSummary {
                Text("المدى: \(range)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onTap) {
                Label("فتح قيام الليل", systemImage: "arrow.up.left.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AamalSecondaryButtonStyle())
            .controlSize(.small)
        }
        .aamalCard()
    }
}
