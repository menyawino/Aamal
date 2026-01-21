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

            if let tasks = category.tasks {
                ForEach(tasks) { task in
                    TaskRow(task: task, store: store, date: date)
                }
            }
        }
        .aamalCard()
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
