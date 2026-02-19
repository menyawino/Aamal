import Foundation
import Combine
import UserNotifications

enum RamadanHabit: String, CaseIterable {
    case fast
    case suhoorMealLikeDinner
    case suhoorPropheticSitting
    case suhoorIntendWorshipStrength
    case suhoorNotFull
    case iftarNotFull
    case iftarSlightHungerForWorship
    case iftarIntendWorshipStrength
    case iftarPropheticSitting
    case iftarDua
    case taraweeh
    case qiyam
    case quranJuz
    case sadaqah

    var title: String {
        switch self {
        case .fast: return "صيام اليوم"
        case .suhoorMealLikeDinner: return "أكلت ما كنت تأكل في عشائك العادي"
        case .suhoorPropheticSitting: return "جلست الجلسة النبوية"
        case .suhoorIntendWorshipStrength: return "نويت التقوي على العبادة"
        case .suhoorNotFull: return "لم تشبع"
        case .iftarNotFull: return "لم تشبع"
        case .iftarSlightHungerForWorship: return "جوع بسيط يقوي على العبادة"
        case .iftarIntendWorshipStrength: return "نويت التقوي على العبادة"
        case .iftarPropheticSitting: return "جلست الجلسة النبوية"
        case .iftarDua: return "دعاء الافطار"
        case .taraweeh: return "صلاة التراويح"
        case .qiyam: return "قيام الليل"
        case .quranJuz: return "ورد القرآن"
        case .sadaqah: return "صدقة اليوم"
        }
    }

    var section: RamadanHabitSection {
        switch self {
        case .suhoorMealLikeDinner, .suhoorPropheticSitting, .suhoorIntendWorshipStrength, .suhoorNotFull:
            return .suhoor
        case .iftarNotFull, .iftarSlightHungerForWorship, .iftarIntendWorshipStrength, .iftarPropheticSitting, .iftarDua:
            return .iftar
        case .fast, .taraweeh, .qiyam, .quranJuz, .sadaqah:
            return .general
        }
    }
}

enum RamadanHabitSection {
    case suhoor
    case iftar
    case general

    var title: String {
        switch self {
        case .suhoor: return "مهام السحور"
        case .iftar: return "مهام الإفطار"
        case .general: return "مهام عامة"
        }
    }
}

struct ProgressPoint: Identifiable, Codable {
    let id: UUID
    let date: Date
    let value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}

struct RamadanProgressPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

struct TaskMissInsight: Identifiable {
    let id: UUID
    let taskName: String
    let categoryName: String
    let completionRate: Double
    let missedCount: Int
    let opportunities: Int
}

struct CategoryCompletionInsight: Identifiable {
    let id = UUID()
    let categoryName: String
    let completionRate: Double
    let completedCount: Int
    let opportunities: Int
}

struct WeekdayCompletionInsight: Identifiable {
    let id = UUID()
    let weekday: Int
    let completionRate: Double
    let completedCount: Int
    let opportunities: Int

    var localizedName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        let names = formatter.weekdaySymbols ?? []
        guard names.indices.contains(weekday - 1) else { return "" }
        return names[weekday - 1]
    }
}

final class TaskStore: ObservableObject {
    @Published var categories: [TaskCategory]
    @Published private(set) var totalXP: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var streak: Int = 0
    @Published private(set) var badges: [String] = []
    @Published private(set) var progressHistory: [ProgressPoint] = []
    @Published private(set) var completedLog: [UUID: Set<Date>] = [:]
    @Published private(set) var tasbihCounts: [String: Int] = [:]
    @Published private(set) var dailyDuaIndex: Int = 0
    @Published private(set) var lastResetDate: Date = Date()
    @Published private(set) var ramadanHabitLog: [String: Set<Date>] = [:]

    private let xpPerLevel: Int = 20
    private var lastCompletionDate: Date?
    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let totalXP = "totalXP"
        static let level = "level"
        static let streak = "streak"
        static let badges = "badges"
        static let progressHistory = "progressHistory"
        static let completedLog = "completedLog"
        static let tasbihCounts = "tasbihCounts"
        static let dailyDuaIndex = "dailyDuaIndex"
        static let lastResetDate = "lastResetDate"
        static let lastCompletionDate = "lastCompletionDate"
        static let ramadanHabitLog = "ramadanHabitLog"
    }

    init(categories: [TaskCategory] = [dailyCategory, quranTasks, fridayTasks, ramadanTasks]) {
        self.categories = categories
        loadData()
        checkAndResetDaily()
        recordProgressSnapshot(for: Date())
        requestNotificationPermission()
    }

    // MARK: - Data Persistence

    private func loadData() {
        totalXP = userDefaults.integer(forKey: Keys.totalXP)
        level = userDefaults.integer(forKey: Keys.level)
        if level == 0 { level = 1 }
        streak = userDefaults.integer(forKey: Keys.streak)
        badges = userDefaults.stringArray(forKey: Keys.badges) ?? []
        dailyDuaIndex = userDefaults.integer(forKey: Keys.dailyDuaIndex)

        if let lastCompletionData = userDefaults.object(forKey: Keys.lastCompletionDate) as? Date {
            lastCompletionDate = lastCompletionData
        }
        if let lastResetData = userDefaults.object(forKey: Keys.lastResetDate) as? Date {
            lastResetDate = lastResetData
        }

        if let historyData = userDefaults.data(forKey: Keys.progressHistory),
           let decoded = try? decoder.decode([ProgressPoint].self, from: historyData) {
            progressHistory = decoded
        }

        if let logData = userDefaults.data(forKey: Keys.completedLog),
           let decoded = try? decoder.decode([String: [Date]].self, from: logData) {
            var log: [UUID: Set<Date>] = [:]
            for (key, dates) in decoded {
                if let uuid = UUID(uuidString: key) {
                    log[uuid] = Set(dates)
                }
            }
            completedLog = log
        }

        if let tasbihData = userDefaults.data(forKey: Keys.tasbihCounts),
           let decoded = try? decoder.decode([String: Int].self, from: tasbihData) {
            tasbihCounts = decoded
        }

        if let ramadanData = userDefaults.data(forKey: Keys.ramadanHabitLog),
           let decoded = try? decoder.decode([String: [Date]].self, from: ramadanData) {
            var log: [String: Set<Date>] = [:]
            for (key, dates) in decoded {
                log[key] = Set(dates)
            }
            ramadanHabitLog = log
        }
    }

    private func saveData() {
        userDefaults.set(totalXP, forKey: Keys.totalXP)
        userDefaults.set(level, forKey: Keys.level)
        userDefaults.set(streak, forKey: Keys.streak)
        userDefaults.set(badges, forKey: Keys.badges)
        userDefaults.set(dailyDuaIndex, forKey: Keys.dailyDuaIndex)
        userDefaults.set(lastResetDate, forKey: Keys.lastResetDate)
        userDefaults.set(lastCompletionDate, forKey: Keys.lastCompletionDate)

        if let historyData = try? encoder.encode(progressHistory) {
            userDefaults.set(historyData, forKey: Keys.progressHistory)
        }

        var log: [String: [Date]] = [:]
        for (key, dates) in completedLog {
            log[key.uuidString] = Array(dates)
        }
        if let logData = try? encoder.encode(log) {
            userDefaults.set(logData, forKey: Keys.completedLog)
        }

        if let tasbihData = try? encoder.encode(tasbihCounts) {
            userDefaults.set(tasbihData, forKey: Keys.tasbihCounts)
        }

        var ramadanLog: [String: [Date]] = [:]
        for (habit, dates) in ramadanHabitLog {
            ramadanLog[habit] = Array(dates)
        }
        if let ramadanData = try? encoder.encode(ramadanLog) {
            userDefaults.set(ramadanData, forKey: Keys.ramadanHabitLog)
        }
    }

    private func checkAndResetDaily() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(lastResetDate) {
            tasbihCounts = [:]
            dailyDuaIndex = Int.random(in: 0..<dailyDuas.count)
            lastResetDate = Date()
            saveData()
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            print("Notification permission: \(granted)")
        }
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

    var todayDua: Dua? {
        guard !dailyDuas.isEmpty else { return nil }
        let index = min(max(dailyDuaIndex, 0), dailyDuas.count - 1)
        return dailyDuas[index]
    }

    var hijriDateText: String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .islamicUmmAlQura)
        formatter.locale = Locale(identifier: "ar")
        formatter.dateFormat = "EEEE d MMMM y"
        return formatter.string(from: Date())
    }

    var weeklyCompletionRate: Double {
        completionRate(forLastDays: 7)
    }

    var monthlyCompletionRate: Double {
        completionRate(forLastDays: 30)
    }

    var todayTasbihTotal: Int {
        tasbihCounts.values.reduce(0, +)
    }

    var isRamadanNow: Bool {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        return calendar.component(.month, from: Date()) == 9
    }

    var ramadanDayNumber: Int {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        return calendar.component(.day, from: Date())
    }

    var ramadanRemainingDaysEstimate: Int {
        max(0, 30 - ramadanDayNumber)
    }

    var ramadanTodayProgress: Double {
        ramadanProgress(on: Date())
    }

    var ramadanFastingStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        while isRamadanDay(cursor), isRamadanHabitCompleted(.fast, on: cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }

        return streak
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

    func tasbihCount(for phrase: String) -> Int {
        tasbihCounts[phrase] ?? 0
    }

    func incrementTasbih(for phrase: String) {
        checkAndResetDaily()
        tasbihCounts[phrase, default: 0] += 1
        saveData()
    }

    func resetTasbih(for phrase: String) {
        tasbihCounts[phrase] = 0
        saveData()
    }

    func pickNextDailyDua() {
        guard !dailyDuas.isEmpty else { return }
        dailyDuaIndex = (dailyDuaIndex + 1) % dailyDuas.count
        saveData()
    }

    func isRamadanHabitCompleted(_ habit: RamadanHabit, on date: Date) -> Bool {
        let day = dateKey(date)
        return ramadanHabitLog[habit.rawValue]?.contains(day) ?? false
    }

    func toggleRamadanHabit(_ habit: RamadanHabit, on date: Date = Date()) {
        let day = dateKey(date)
        var entries = ramadanHabitLog[habit.rawValue] ?? []
        if entries.contains(day) {
            entries.remove(day)
        } else {
            entries.insert(day)
        }
        ramadanHabitLog[habit.rawValue] = entries.isEmpty ? nil : entries
        saveData()
    }

    func ramadanProgress(on date: Date) -> Double {
        guard !RamadanHabit.allCases.isEmpty else { return 0 }
        let done = RamadanHabit.allCases.filter { isRamadanHabitCompleted($0, on: date) }.count
        return Double(done) / Double(RamadanHabit.allCases.count)
    }

    func completionSeries(days: Int) -> [ProgressPoint] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -(days - 1 - offset), to: today) else {
                return nil
            }
            return ProgressPoint(date: date, value: completion(for: categories, on: date))
        }
    }

    func mostMissedTasks(days: Int, limit: Int = 5) -> [TaskMissInsight] {
        let windowDates = lastNDates(days: days)
        guard !windowDates.isEmpty else { return [] }

        let insights = allTasks.compactMap { task -> TaskMissInsight? in
            var opportunities = 0
            var completed = 0

            for day in windowDates where isTaskActive(task, on: day) {
                opportunities += 1
                if isTaskCompleted(task, on: day) {
                    completed += 1
                }
            }

            guard opportunities > 0 else { return nil }
            let missed = opportunities - completed
            guard missed > 0 else { return nil }

            return TaskMissInsight(
                id: task.id,
                taskName: task.name,
                categoryName: task.category,
                completionRate: Double(completed) / Double(opportunities),
                missedCount: missed,
                opportunities: opportunities
            )
        }

        return insights
            .sorted {
                if $0.completionRate == $1.completionRate {
                    return $0.missedCount > $1.missedCount
                }
                return $0.completionRate < $1.completionRate
            }
            .prefix(limit)
            .map { $0 }
    }

    func categoryCompletionInsights(days: Int, limit: Int = 4) -> [CategoryCompletionInsight] {
        let windowDates = lastNDates(days: days)
        guard !windowDates.isEmpty else { return [] }

        let groupedTasks = Dictionary(grouping: allTasks, by: \ .category)
        let insights = groupedTasks.compactMap { entry -> CategoryCompletionInsight? in
            let tasks = entry.value
            guard !tasks.isEmpty else { return nil }

            var opportunities = 0
            var completed = 0
            for day in windowDates {
                for task in tasks where isTaskActive(task, on: day) {
                    opportunities += 1
                    if isTaskCompleted(task, on: day) {
                        completed += 1
                    }
                }
            }

            guard opportunities > 0 else { return nil }

            return CategoryCompletionInsight(
                categoryName: entry.key,
                completionRate: Double(completed) / Double(opportunities),
                completedCount: completed,
                opportunities: opportunities
            )
        }

        return insights
            .sorted {
                if $0.completionRate == $1.completionRate {
                    return $0.opportunities > $1.opportunities
                }
                return $0.completionRate > $1.completionRate
            }
            .prefix(limit)
            .map { $0 }
    }

    func weakestWeekdayInsight(days: Int) -> WeekdayCompletionInsight? {
        weekdayCompletionInsights(days: days).min { $0.completionRate < $1.completionRate }
    }

    func strongestWeekdayInsight(days: Int) -> WeekdayCompletionInsight? {
        weekdayCompletionInsights(days: days).max { $0.completionRate < $1.completionRate }
    }

    func consistencyRate(days: Int, minimumDailyCompletion: Double = 0.6) -> Double {
        let windowDates = lastNDates(days: days)
        guard !windowDates.isEmpty else { return 0 }

        let consistentDays = windowDates.filter {
            completion(for: categories, on: $0) >= minimumDailyCompletion
        }.count

        return Double(consistentDays) / Double(windowDates.count)
    }

    private func weekdayCompletionInsights(days: Int) -> [WeekdayCompletionInsight] {
        let calendar = Calendar.current
        let windowDates = lastNDates(days: days)
        guard !windowDates.isEmpty else { return [] }

        var perWeekday: [Int: (completed: Int, opportunities: Int)] = [:]
        for day in windowDates {
            let weekday = calendar.component(.weekday, from: day)
            let tasks = allTasks.filter { isTaskActive($0, on: day) }
            guard !tasks.isEmpty else { continue }
            let completed = tasks.filter { isTaskCompleted($0, on: day) }.count
            let current = perWeekday[weekday] ?? (0, 0)
            perWeekday[weekday] = (current.completed + completed, current.opportunities + tasks.count)
        }

        return perWeekday.compactMap { weekday, stats in
            guard stats.opportunities > 0 else { return nil }
            return WeekdayCompletionInsight(
                weekday: weekday,
                completionRate: Double(stats.completed) / Double(stats.opportunities),
                completedCount: stats.completed,
                opportunities: stats.opportunities
            )
        }
    }

    func ramadanSeries(maxDays: Int = 30) -> [RamadanProgressPoint] {
        guard maxDays > 0 else { return [] }

        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let gregorian = Calendar.current
        let today = gregorian.startOfDay(for: Date())

        guard let ramadanStart = hijri.date(from: DateComponents(
            calendar: hijri,
            year: hijri.component(.year, from: today),
            month: 9,
            day: 1
        )) else {
            return []
        }

        let normalizedStart = gregorian.startOfDay(for: ramadanStart)

        return (0..<maxDays).compactMap { dayIndex in
            guard let date = gregorian.date(byAdding: .day, value: dayIndex, to: normalizedStart) else {
                return nil
            }
            guard date <= today else { return nil }
            return RamadanProgressPoint(date: date, value: ramadanProgress(on: date))
        }
    }

    func isRamadanDay(_ date: Date) -> Bool {
        let calendar = Calendar(identifier: .islamicUmmAlQura)
        return calendar.component(.month, from: date) == 9
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
                            saveData()
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
                        saveData()
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
        recordProgressSnapshot(for: Date())
        saveData()
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
                            saveData()
                        } else {
                            recordProgressSnapshot(for: dayKey)
                            saveData()
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
                        saveData()
                    } else {
                        recordProgressSnapshot(for: dayKey)
                        saveData()
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
        saveData()
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

        saveData()
    }

    private func completionRate(forLastDays days: Int) -> Double {
        guard days > 0 else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let totalOpportunities = allTasks.count * days
        guard totalOpportunities > 0 else { return 0 }

        var completed = 0
        for offset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            completed += allTasks.filter { isTaskCompleted($0, on: date) }.count
        }

        return Double(completed) / Double(totalOpportunities)
    }

    private func lastNDates(days: Int) -> [Date] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    private func isTaskActive(_ task: Task, on date: Date) -> Bool {
        if task.category == "وظائف الجمعة" {
            return Calendar.current.component(.weekday, from: date) == 6
        }
        return true
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

            if self.isRamadanNow {
                if let suhoorTime = Calendar.current.date(byAdding: .minute, value: -45, to: timings.fajr) {
                    self.scheduleNotification(
                        id: "ramadan_suhoor",
                        title: "تذكير السحور",
                        body: "تبقى 45 دقيقة على الفجر، لا تنسَ نية الصيام.",
                        date: suhoorTime
                    )
                }

                if let iftarPrep = Calendar.current.date(byAdding: .minute, value: -10, to: timings.maghrib) {
                    self.scheduleNotification(
                        id: "ramadan_iftar",
                        title: "تذكير الإفطار",
                        body: "اقترب وقت المغرب، جهّز دعاء الإفطار.",
                        date: iftarPrep
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
            "wudu_Fajr", "wudu_Dhuhr", "wudu_Asr", "wudu_Maghrib", "wudu_Isha",
            "ramadan_suhoor", "ramadan_iftar"]
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
