import SwiftUI
import CoreLocation

struct GamifiedHomeView: View {
    @ObservedObject var store: TaskStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel: PrayerTimesViewModel

    init(store: TaskStore) {
        self.store = store
        _prayerViewModel = StateObject(wrappedValue: PrayerTimesViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HeroProgressCard(store: store)
                    TimeBoundTasksCard(store: store, timings: prayerViewModel.timings)
                    QuickLogSection(store: store, onlyNonPrayer: true, allowedPrayer: currentPrayerName)

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
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("أعمال")
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, location in
            guard let location else { return }
            prayerViewModel.refresh(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }

    private var currentPrayerName: String? {
        guard let timings = prayerViewModel.timings else { return nil }
        let slots = timings.slots().sorted(by: { $0.date < $1.date })
        let now = Date()

        for index in slots.indices {
            let current = slots[index]
            let next = index + 1 < slots.count ? slots[index + 1] : nil

            if now >= current.date && (next == nil || now < next!.date) {
                return current.arabicName
            }
        }

        return nil
    }

    private func isFriday() -> Bool {
        Calendar.current.component(.weekday, from: Date()) == 6
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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("تسجيل سريع")
                .font(.headline)

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
        let pending = store.allTasks.filter { !store.isTaskCompleted($0, on: Date()) }

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
    }
}

private struct TaskCategoryCard: View {
    let category: TaskCategory
    @ObservedObject var store: TaskStore

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

                if let subCategories = category.subCategories,
                   let azkar = subCategories.first(where: { $0.name == "الاذكار المقيدة" }) {
                    CompactTaskList(title: azkar.name, tasks: azkar.tasks, store: store)
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
    let timings: PrayerTimings?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("مهام وقت الصلاة")
                .font(.headline)

            if let currentPrayer = currentPrayerName {
                PrayerTaskGroupCard(prayerName: currentPrayer, tasks: store.tasks(forPrayerName: currentPrayer), store: store)
            } else {
                Text("لا توجد مهام صلاة حالياً")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .aamalCard()
    }

    private var currentPrayerName: String? {
        guard let timings else { return nil }
        let slots = timings.slots().sorted(by: { $0.date < $1.date })
        let now = Date()

        for index in slots.indices {
            let current = slots[index]
            let next = index + 1 < slots.count ? slots[index + 1] : nil

            if now >= current.date && (next == nil || now < next!.date) {
                return current.arabicName
            }
        }

        return nil
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

    private var completion: Double {
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { store.isTaskCompleted($0, on: Date()) }.count
        return Double(completed) / Double(tasks.count)
    }

    private var upcomingTasks: [Task] {
        Array(tasks.filter { !store.isTaskCompleted($0, on: Date()) }.prefix(2))
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

            if upcomingTasks.isEmpty {
                Text("كل مهام الصلاة مكتملة")
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
                        .buttonStyle(.borderedProminent)
                        .tint(AamalTheme.emerald)
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
                .fill(Color.white.opacity(0.6))
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
                .fill(Color.white.opacity(0.6))
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
                Button(action: {
                    store.toggleTask(taskId: task.id, on: Date())
                }) {
                    Text("تم")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BorderedButtonStyle())

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
