import SwiftUI
import CoreLocation
import UIKit

struct GamifiedHomeView: View {
    @ObservedObject var store: TaskStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel: PrayerTimesViewModel

    init(store: TaskStore) {
        self.store = store
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
                VStack(spacing: 16) {
                    HeroProgressCard(store: store)
                    HomeTodayStatusCard(
                        completedCount: completedTodayCount,
                        pendingCount: pendingTodayCount,
                        nextPrayerName: nextPrayerSlot?.arabicName
                    )
                    HomeQuickActionsCard(
                        refreshAction: { refreshPrayerTimes(force: true) }
                    )
                    TimeBoundTasksCard(store: store, nextPrayer: nextPrayerSlot)
                    QuickLogSection(store: store, onlyNonPrayer: true, allowedPrayer: nextPrayerSlot?.arabicName)

                    ForEach(store.categories, id: \.name) { category in
                        if category.name == "مهام الجمعة" && !isFriday() {
                            EmptyView()
                        } else if category.name == "اليومي" {
                            EmptyView()
                        } else {
                            TaskCategoryCard(category: category, store: store)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
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
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("أعمال")
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
        locationManager.requestLocation()
        guard let location = locationManager.location else { return }
        prayerViewModel.refresh(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            fallbackCity: locationManager.city,
            fallbackCountry: locationManager.country,
            force: force
        )
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
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("ملخص سريع")
                    .font(.headline)
                Text("المتبقي اليوم: \(pendingCount)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("المكتمل: \(completedCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let nextPrayerName {
                    Text("الصلاة القادمة: \(nextPrayerName)")
                        .font(.caption)
                        .foregroundColor(AamalTheme.emerald)
                }
            }
        }
        .aamalCard()
    }
}

private struct HomeQuickActionsCard: View {
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("التسجيل من الصفحة الرئيسية يتم مهمة بمهمة")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: refreshAction) {
                Label("تحديث الأوقات", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AamalTheme.gold)
        }
        .controlSize(.small)
        .aamalCard()
    }
}



private struct HeroProgressCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("رحلة اليوم")
                        .font(.headline)
                        .foregroundColor(AamalTheme.ink)
                    Text("المستوى \(store.level) • \(store.totalXP) نقطة")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("سلسلة الإنجاز")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.streak) أيام")
                        .font(.headline)
                        .foregroundColor(AamalTheme.emerald)
                }
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
        .aamalCard()
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("تسجيل سريع")
                    .font(.headline)
                Text("أنجز بسرعة أهم المهام المتبقية اليوم")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

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
                store.toggleTask(taskId: task.id, on: Date())
            }) {
                Text("سجل")
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.emerald)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(category.name)
                    .font(.headline)
                Spacer()
                Text("\(Int(store.completion(for: category) * 100))%")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

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
        VStack(alignment: .leading, spacing: 12) {
            Text("المهام المرتبطة بالصلاة القادمة")
                .font(.headline)

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
        VStack(spacing: 12) {
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
        VStack(alignment: .leading, spacing: 8) {
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
                            store.toggleTask(taskId: task.id, on: Date())
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AamalTheme.emerald)
                        .controlSize(.small)
                    }
                }

                if pendingTasks.count > 2 {
                    Button(showAllPending ? "إخفاء بعض المهام" : "عرض كل المهام المتبقية") {
                        showAllPending.toggle()
                    }
                    .buttonStyle(.bordered)
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
        )
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
        VStack(alignment: .leading, spacing: 8) {
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
                            store.toggleTask(taskId: task.id, on: Date())
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
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
        )
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
                    store.unlogTask(taskId: task.id, on: Date())
                }) {
                    Text("إلغاء التسجيل")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: {
                    store.toggleTask(taskId: task.id, on: Date())
                }) {
                    Text("سجل")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(AamalTheme.emerald)
            }

        }
        .padding(.vertical, 4)
    }
}
