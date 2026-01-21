import SwiftUI
import UserNotifications

struct TaskListView: View {
    @State private var tasks: [Task] = [
        Task(name: "الاستيقاظ", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الخلاء", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "لبس الثوب وخلعه", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الوضوء", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "دخول المنزل والخروج", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "المسجد (دخول وخروج)", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "المشي إلى المسجد", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الأكل والشرب", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الركوب", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "النوم", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "حضور دروس العلم (السبت والخميس)", score: 5, category: "علم", isCompleted: false, level: 1, badge: nil),
        Task(name: "مذاكرة دروس العلم", score: 5, category: "علم", isCompleted: false, level: 1, badge: nil),
        Task(name: "بر الوالدين", score: 5, category: "الأسرة", isCompleted: false, level: 1, badge: nil),
        Task(name: "مذاكرة الدراسة أو إتقان العمل الدنيوي (خمس ساعات)", score: 5, category: "عمل", isCompleted: false, level: 1, badge: nil),
        Task(name: "سنن الفطرة", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الغسل", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الطيب", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "السواك", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "التبكير", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "سورة الكهف", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الصلاة على النبي 100", score: 1, category: "مهام الجمعة", isCompleted: false, level: 1, badge: nil)
    ]

    var body: some View {
        NavigationView {
            List {
                ForEach($tasks) { $task in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(task.name)
                                .font(.headline)
                            Text("النقاط: \(task.score)")
                                .font(.subheadline)
                            if let badge = task.badge {
                                Text("وسام: \(badge)")
                                    .font(.subheadline)
                                    .foregroundColor(.blue)
                            }
                        }
                        Spacer()
                        Button(action: {
                            task.toggleCompletion()
                            if task.isCompleted {
                                task.upgradeLevel()
                                task.assignBadge("نجم متميز")
                                scheduleNotification(for: task.name)
                            }
                        }) {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(task.isCompleted ? .green : .gray)
                        }
                    }
                }
            }
            .navigationTitle("المهام")
        }
    }

    func scheduleNotification(for taskName: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = "تمت المهمة"
        content.body = "أكملت \(taskName). أحسنت!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "taskCompletion_\(taskName)", content: content, trigger: trigger)

        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
}

struct TaskTableView: View {
    let taskCategories: [TaskCategory] = [dailyCategory, quranTasks, fridayTasks]
    @State private var currentDate = Date()
    @State private var currentTime = ""

    var body: some View {
        NavigationView {
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
        return weekday == 6 // Friday is the 6th day in the Gregorian calendar
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