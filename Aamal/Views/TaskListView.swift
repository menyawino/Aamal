import SwiftUI
import UserNotifications

struct TaskListView: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(store.allTasks.enumerated()), id: \.element.id) { _, task in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(task.name)
                                .font(.headline)
                            Text("النقاط: \(task.score)")
                                .font(.subheadline)
                            if let badge = task.badge {
                                Text("وسام: \(badge)")
                                    .font(.subheadline)
                                    .foregroundColor(AamalTheme.gold)
                            }
                        }
                        Spacer()
                        Button(action: {
                            store.toggleTask(taskId: task.id, on: Date())
                        }) {
                            Image(systemName: store.isTaskCompleted(task, on: Date()) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(store.isTaskCompleted(task, on: Date()) ? AamalTheme.emerald : .secondary)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("المهام")
        }
    }
}

struct TaskTableView: View {
    let taskCategories: [TaskCategory] = [dailyCategory, fridayTasks]
    @State private var currentDate = Date()
    @State private var currentTime = ""

    var body: some View {
        NavigationStack {
            VStack {
                Text("مهام الأسبوع")
                    .font(.title)
                    .padding()

                ScrollView {
                    ForEach(taskCategories, id: \ .name) { category in
                        if category.name == "مهام الجمعة" {
                            if isFriday() {
                                displayCategory(category)
                            }
                        } else {
                            displayCategory(category)
                        }
                    }
                }
            }
            .navigationTitle("مهام الأسبوع")
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .onAppear {
                currentDate = Date()
                currentTime = fetchCurrentTime()
            }
        }
    }

    private func displayCategory(_ category: TaskCategory) -> some View {
        VStack(alignment: .leading) {
            Text(category.name)
                .font(.headline)
                .padding(.top)

            if let subCategories = category.subCategories {
                ForEach(subCategories, id: \ .name) { subCategory in
                    VStack(alignment: .leading) {
                        Text(subCategory.name)
                            .font(.subheadline)
                            .padding(.top)

                        ProgressView(value: calculateCategoryPercentage(tasks: subCategory.tasks) / 100)
                            .padding(.vertical)

                        ForEach(subCategory.tasks) { task in
                            HStack {
                                Text(task.name)
                                    .font(.subheadline)
                                Spacer()
                                Text("النقاط: \(task.score)")
                                    .font(.subheadline)
                                if isTimeBound(task: task) {
                                    Text("محدد بالوقت")
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            } else if let tasks = category.tasks {
                ProgressView(value: calculateCategoryPercentage(tasks: tasks) / 100)
                    .padding(.vertical)

                ForEach(tasks) { task in
                    HStack {
                        Text(task.name)
                            .font(.subheadline)
                        Spacer()
                        Text("النقاط: \(task.score)")
                            .font(.subheadline)
                        if isTimeBound(task: task) {
                            Text("محدد بالوقت")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
        }
    }

    private func isFriday() -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        return weekday == 6
    }

    private func fetchCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }

    private func isTimeBound(task: Task) -> Bool {
        // Example logic for time-bound tasks
        let timeBoundTasks = ["الصبح", "الظهر", "العصر", "المغرب", "العشاء"]
        return timeBoundTasks.contains(task.category)
    }

    private func calculateCategoryPercentage(tasks: [Task]) -> Double {
        let totalScore = tasks.reduce(0) { $0 + $1.score }
        let completedScore = tasks.filter { $0.isCompleted }.reduce(0) { $0 + $1.score }
        return totalScore > 0 ? (Double(completedScore) / Double(totalScore)) * 100 : 0.0
    }
}