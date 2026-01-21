import Foundation
import Combine
import UserNotifications

struct ProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

final class TaskStore: ObservableObject {
    @Published var categories: [TaskCategory]
    @Published private(set) var totalXP: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var streak: Int = 0
    @Published private(set) var badges: [String] = []
    @Published private(set) var progressHistory: [ProgressPoint] = []
    @Published private(set) var completedLog: [UUID: Set<Date>] = [:]

    private let xpPerLevel: Int = 20
    private var lastCompletionDate: Date?

    init(categories: [TaskCategory] = [dailyCategory, quranTasks, fridayTasks]) {
        self.categories = categories
        recordProgressSnapshot(for: Date())
    }

    var totalTaskCount: Int {
        allTasks.count
    }

    var completedTaskCount: Int {
        allTasks.filter { isTaskCompleted($0, on: Date()) }.count
    }

    var overallProgress: Double {
        completion(for: categories)
    }

    var levelProgress: Double {
        let currentLevelXP = totalXP % xpPerLevel
        return Double(currentLevelXP) / Double(xpPerLevel)
    }

    var xpToNextLevel: Int {
        let currentLevelXP = totalXP % xpPerLevel
        return max(0, xpPerLevel - currentLevelXP)
    }

    var allTasks: [Task] {
        categories.flatMap { category in
            var tasks: [Task] = []
            if let subCategories = category.subCategories {
                for sub in subCategories {
                    tasks.append(contentsOf: sub.tasks)
                }
            }
            if let directTasks = category.tasks {
                tasks.append(contentsOf: directTasks)
            }
            return tasks
        }
    }

    var prayerNames: [String] {
        ["الصبح", "الظهر", "العصر", "المغرب", "العشاء"]
    }

    func isPrayerTask(_ task: Task) -> Bool {
        prayerNames.contains(task.category)
    }

    func tasks(forPrayerName prayerName: String) -> [Task] {
        allTasks.filter { $0.category == prayerName }
    }

    func wuduTasks() -> [Task] {
        allTasks.filter { $0.name.contains("الوضوء") }
    }

    func completion(for category: TaskCategory) -> Double {
        completion(for: [category])
    }

    func completion(for categories: [TaskCategory], on date: Date = Date()) -> Double {
        let tasks = categories.flatMap { tasksForCategory($0) }
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { isTaskCompleted($0, on: date) }.count
        return Double(completed) / Double(tasks.count)
    }

    func nextUpTasks(limit: Int, on date: Date = Date()) -> [Task] {
        Array(allTasks.filter { !isTaskCompleted($0, on: date) }.prefix(limit))
    }

    func toggleTask(taskId: UUID, on date: Date = Date()) {
        let dayKey = dateKey(date)
        let isToday = Calendar.current.isDateInToday(dayKey)
        for categoryIndex in categories.indices {
            if var subCategories = categories[categoryIndex].subCategories {
                for subIndex in subCategories.indices {
                    if let taskIndex = subCategories[subIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                        let task = subCategories[subIndex].tasks[taskIndex]
                        let wasCompleted = isTaskCompleted(task, on: dayKey)
                        setCompletion(taskId: taskId, completed: !wasCompleted, on: dayKey)

                        if isToday {
                            subCategories[subIndex].tasks[taskIndex].isCompleted = !wasCompleted
                        }
                        categories[categoryIndex].subCategories = subCategories

                        if isToday {
                            handleCompletionChange(task: task, wasCompleted: wasCompleted)
                        } else {
                            recordProgressSnapshot(for: dayKey)
                        }
                        return
                    }
                }
            }

            if var tasks = categories[categoryIndex].tasks {
                if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = tasks[taskIndex]
                    let wasCompleted = isTaskCompleted(task, on: dayKey)
                    setCompletion(taskId: taskId, completed: !wasCompleted, on: dayKey)
                    if isToday {
                        tasks[taskIndex].isCompleted = !wasCompleted
                    }
                    categories[categoryIndex].tasks = tasks

                    if isToday {
                        handleCompletionChange(task: task, wasCompleted: wasCompleted)
                    } else {
                        recordProgressSnapshot(for: dayKey)
                    }
                    return
                }
            }
        }
    }

    func isTaskCompleted(_ task: Task, on date: Date) -> Bool {
        let dayKey = dateKey(date)
        return completedLog[task.id]?.contains(dayKey) ?? false
    }

    func removeTask(taskId: UUID) {
        for categoryIndex in categories.indices {
            if var subCategories = categories[categoryIndex].subCategories {
                for subIndex in subCategories.indices {
                    subCategories[subIndex].tasks.removeAll { $0.id == taskId }
                }
                categories[categoryIndex].subCategories = subCategories
            }

            if var tasks = categories[categoryIndex].tasks {
                tasks.removeAll { $0.id == taskId }
                categories[categoryIndex].tasks = tasks
            }
        }

        completedLog[taskId] = nil
        recordProgressSnapshot()
    }

    func unlogTask(taskId: UUID, on date: Date = Date()) {
        let dayKey = dateKey(date)
        let isToday = Calendar.current.isDateInToday(dayKey)
        for categoryIndex in categories.indices {
            if let subCategories = categories[categoryIndex].subCategories {
                var updated = subCategories
                for subIndex in updated.indices {
                    if let taskIndex = updated[subIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                        let task = updated[subIndex].tasks[taskIndex]
                        let wasCompleted = isTaskCompleted(task, on: dayKey)
                        guard wasCompleted else { return }

                        setCompletion(taskId: taskId, completed: false, on: dayKey)

                        if isToday {
                            updated[subIndex].tasks[taskIndex].isCompleted = false
                            categories[categoryIndex].subCategories = updated
                            totalXP = max(0, totalXP - task.score)
                            updateLevel()
                            recordProgressSnapshot(for: dayKey)
                        } else {
                            recordProgressSnapshot(for: dayKey)
                        }
                        return
                    }
                }
            }

            if let tasks = categories[categoryIndex].tasks,
               tasks.contains(where: { $0.id == taskId }) {
                var updated = tasks
                if let taskIndex = updated.firstIndex(where: { $0.id == taskId }) {
                    let task = updated[taskIndex]
                    let wasCompleted = isTaskCompleted(task, on: dayKey)
                    guard wasCompleted else { return }

                    setCompletion(taskId: taskId, completed: false, on: dayKey)

                    if isToday {
                        updated[taskIndex].isCompleted = false
                        categories[categoryIndex].tasks = updated
                        totalXP = max(0, totalXP - task.score)
                        updateLevel()
                        recordProgressSnapshot(for: dayKey)
                    } else {
                        recordProgressSnapshot(for: dayKey)
                    }
                }
                return
            }
        }
    }

    private func handleCompletionChange(task: Task, wasCompleted: Bool) {
        if !wasCompleted && task.isCompleted {
            totalXP += task.score
            updateLevel()
            updateStreakOnCompletion()
            checkBadges()
        } else if wasCompleted && !task.isCompleted {
            totalXP = max(0, totalXP - task.score)
            updateLevel()
        }

        recordProgressSnapshot(for: Date())
    }

    private func updateLevel() {
        level = max(1, totalXP / xpPerLevel + 1)
    }

    private func updateStreakOnCompletion() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastDate = lastCompletionDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            if lastDay == today {
                return
            }

            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            if yesterday == lastDay {
                streak += 1
            } else {
                streak = 1
            }
        } else {
            streak = 1
        }

        lastCompletionDate = today

        if streak == 7 {
            addBadge("سلسلة ٧ أيام")
        }
        if streak == 30 {
            addBadge("سلسلة ٣٠ يومًا")
        }
    }

    private func checkBadges() {
        for category in categories {
            if completion(for: category) >= 1 {
                switch category.name {
                case "اليومي":
                    addBadge("بطل الأعمال اليومية")
                case "القرآن":
                    addBadge("حافظ القرآن")
                case "مهام الجمعة":
                    addBadge("منجز مهام الجمعة")
                default:
                    addBadge("متميز في \(category.name)")
                }
            }
        }
    }

    private func addBadge(_ badge: String) {
        guard !badges.contains(badge) else { return }
        badges.append(badge)
    }

    func recordProgressSnapshot(for date: Date) {
        let dayKey = dateKey(date)
        let value = completion(for: categories, on: dayKey)

        if let index = progressHistory.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: dayKey) }) {
            progressHistory[index] = ProgressPoint(date: dayKey, value: value)
        } else {
            progressHistory.append(ProgressPoint(date: dayKey, value: value))
        }

        progressHistory.sort { $0.date < $1.date }
        if progressHistory.count > 30 {
            progressHistory.removeFirst(progressHistory.count - 30)
        }
    }

    func schedulePrayerNotifications(timings: PrayerTimings) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: self.notificationIdentifiers())

            for slot in timings.slots() {
                let prayerTasks = self.tasks(forPrayerName: slot.arabicName)
                let taskNames = prayerTasks.map { $0.name }.joined(separator: "، ")
                let prayerBody = taskNames.isEmpty ? "حان وقت الصلاة" : "مهام الصلاة: \(taskNames)"

                self.scheduleNotification(
                    id: "prayer_\(slot.apiKey)",
                    title: "\(slot.arabicName)",
                    body: prayerBody,
                    date: slot.date
                )

                if let wuduTime = Calendar.current.date(byAdding: .minute, value: -10, to: slot.date) {
                    let wuduTaskNames = self.wuduTasks().map { $0.name }.joined(separator: "، ")
                    let wuduBody = wuduTaskNames.isEmpty ? "تذكير بالوضوء" : "تذكير: \(wuduTaskNames)"

                    self.scheduleNotification(
                        id: "wudu_\(slot.apiKey)",
                        title: "تذكير الوضوء قبل \(slot.arabicName)",
                        body: wuduBody,
                        date: wuduTime
                    )
                }
            }
        }
    }

    private func scheduleNotification(id: String, title: String, body: String, date: Date) {
        guard date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func notificationIdentifiers() -> [String] {
        ["prayer_Fajr", "prayer_Dhuhr", "prayer_Asr", "prayer_Maghrib", "prayer_Isha",
         "wudu_Fajr", "wudu_Dhuhr", "wudu_Asr", "wudu_Maghrib", "wudu_Isha"]
    }

    private func tasksForCategory(_ category: TaskCategory) -> [Task] {
        var tasks: [Task] = []
        if let subCategories = category.subCategories {
            for sub in subCategories {
                tasks.append(contentsOf: sub.tasks)
            }
        }
        if let directTasks = category.tasks {
            tasks.append(contentsOf: directTasks)
        }
        return tasks
    }

    private func dateKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func setCompletion(taskId: UUID, completed: Bool, on date: Date) {
        var entries = completedLog[taskId] ?? []
        if completed {
            entries.insert(date)
        } else {
            entries.remove(date)
        }
        completedLog[taskId] = entries.isEmpty ? nil : entries
    }
}
