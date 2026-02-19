import SwiftUI

struct DailyTasksView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("تسجيل أيام سابقة")
                            .font(.headline)
                        DatePicker("اختر التاريخ", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Text("يمكنك تسجيل إنجازات أي يوم سابق هنا")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .aamalCard()

                    ForEach(store.categories, id: \.name) { category in
                        if category.name == "مهام الجمعة" && !isFriday(selectedDate) {
                            EmptyView()
                        } else {
                            CategorySectionView(category: category, store: store, date: selectedDate)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("أعمال اليوم")
        }
    }

    private func isFriday(_ date: Date) -> Bool {
        Calendar.current.component(.weekday, from: date) == 6
    }
}

private struct CategorySectionView: View {
    let category: TaskCategory
    @ObservedObject var store: TaskStore
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.name)
                .font(.headline)

            if let subCategories = category.subCategories {
                ForEach(subCategories, id: \.name) { subCategory in
                    if subCategory.tasks.allSatisfy({ store.isPrayerTask($0) }) {
                        PrayerCompactGroupList(tasks: subCategory.tasks, store: store, date: date)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(subCategory.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(subCategory.tasks) { task in
                                TaskRow(task: task, store: store, date: date)
                            }
                        }
                    }
                }
            }

            if let tasks = category.tasks {
                ForEach(tasks) { task in
                    TaskRow(task: task, store: store, date: date)
                }
            }
        }
        .aamalCard()
    }
}

private struct PrayerCompactGroupList: View {
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date

    private var grouped: [String: [Task]] {
        Dictionary(grouping: tasks, by: { $0.category })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مهام الصلاة")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(grouped.keys.sorted(), id: \.self) { prayer in
                PrayerTinyGroupRow(prayerName: prayer, tasks: grouped[prayer] ?? [], store: store, date: date)
            }
        }
    }
}

private struct PrayerTinyGroupRow: View {
    let prayerName: String
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date
    @State private var isExpanded = false

    private var remainingCount: Int {
        tasks.filter { !store.isTaskCompleted($0, on: date) }.count
    }

    private var previewTasks: [Task] {
        isExpanded ? tasks : Array(tasks.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(prayerName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AamalTheme.emerald.opacity(0.15))
                    .foregroundColor(AamalTheme.emerald)
                    .clipShape(Capsule())

                Text("\(remainingCount) متبقية")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(previewTasks) { task in
                TaskRow(task: task, store: store, date: date)
            }

            if tasks.count > previewTasks.count {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "عرض أقل" : "+\(tasks.count - previewTasks.count) مهام أخرى")
                            .font(.caption2)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else if tasks.count > 2 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("عرض أقل")
                            .font(.caption2)
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct TaskRow: View {
    let task: Task
    @ObservedObject var store: TaskStore
    let date: Date

    var body: some View {
        let isCompleted = store.isTaskCompleted(task, on: date)
        HStack(spacing: 12) {
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
                    store.toggleTask(taskId: task.id, on: date)
                }) {
                    Text("تم")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BorderedButtonStyle())

                Button(action: {
                    store.unlogTask(taskId: task.id, on: date)
                }) {
                    Text("إلغاء التسجيل")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: {
                    store.toggleTask(taskId: task.id, on: date)
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
