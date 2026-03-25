import Foundation
import Combine
import UserNotifications

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
    @Published private(set) var compensationProgress = CompensationProgress()
    @Published private(set) var quranRevisionPlan = QuranRevisionPlan()

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
        static let compensationProgress = "compensationProgress"
        static let quranRevisionPlan = "quranRevisionPlan"
    }

    init(categories: [TaskCategory] = [dailyCategory, fridayTasks]) {
        self.categories = categories
        loadData()
        removeLegacyRamadanData()
        pruneCompletedLog()
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

        if let compensationData = userDefaults.data(forKey: Keys.compensationProgress),
           let decoded = try? decoder.decode(CompensationProgress.self, from: compensationData) {
            compensationProgress = decoded
            compensationProgress.normalize()
        }

        if let revisionData = userDefaults.data(forKey: Keys.quranRevisionPlan),
           let decoded = try? decoder.decode(QuranRevisionPlan.self, from: revisionData) {
            quranRevisionPlan = decoded
            quranRevisionPlan.normalize()
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

        if let compensationData = try? encoder.encode(compensationProgress) {
            userDefaults.set(compensationData, forKey: Keys.compensationProgress)
        }

        if let revisionData = try? encoder.encode(quranRevisionPlan) {
            userDefaults.set(revisionData, forKey: Keys.quranRevisionPlan)
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

    var totalPrayerDebtCount: Int {
        PrayerCompensationType.allCases.reduce(0) { partial, prayer in
            partial + (compensationProgress.prayerDebtCounts[prayer.rawValue] ?? 0)
        }
    }

    var totalCompensatedPrayerCount: Int {
        PrayerCompensationType.allCases.reduce(0) { partial, prayer in
            partial + (compensationProgress.compensatedPrayerCounts[prayer.rawValue] ?? 0)
        }
    }

    var remainingPrayerDebtCount: Int {
        max(0, totalPrayerDebtCount - totalCompensatedPrayerCount)
    }

    var remainingFastingDebtDays: Int {
        max(0, compensationProgress.fastingDebtDays - compensationProgress.compensatedFastingDays)
    }

    var totalCompensationDebtUnits: Int {
        totalPrayerDebtCount + compensationProgress.fastingDebtDays
    }

    var totalCompensatedDebtUnits: Int {
        totalCompensatedPrayerCount + compensationProgress.compensatedFastingDays
    }

    var compensationCompletionRate: Double {
        guard totalCompensationDebtUnits > 0 else { return 0 }
        return Double(totalCompensatedDebtUnits) / Double(totalCompensationDebtUnits)
    }

    var compensationRankTitle: String {
        switch compensationCompletionRate {
        case 1...:
            return "محرر الذمة"
        case 0.75...:
            return "ثابت في القضاء"
        case 0.4...:
            return "صاعد بثبات"
        case 0.1...:
            return "بداية قوية"
        default:
            return "قيد الانطلاق"
        }
    }

    var compensationSuggestedFocus: String {
        if remainingFastingDebtDays > 0 {
            return "ابدأ بيوم صيام قضاء لتقليل الرصيد الأكبر أثرًا."
        }

        if let prayer = PrayerCompensationType.allCases.max(by: { remainingPrayerDebt(for: $0) < remainingPrayerDebt(for: $1) }),
           remainingPrayerDebt(for: prayer) > 0 {
            return "ركز اليوم على قضاء \(prayer.arabicName) لتخفيف المتبقي سريعًا."
        }

        return "ذمتك خفيفة الآن. حافظ على الثبات اليومي."
    }

    var quranRevisionCompletionRate: Double {
        guard quranRevisionPlan.totalMemorizedRubs > 0 else { return 0 }
        let completedRubs = quranRevisionPlan.completedDates.count * quranRevisionPlan.dailyGoalRubs
        let cycleRubs = completedRubs % quranRevisionPlan.totalMemorizedRubs
        return Double(cycleRubs) / Double(quranRevisionPlan.totalMemorizedRubs)
    }

    var quranRevisionRankTitle: String {
        switch quranRevisionPlan.streak {
        case 30...:
            return "حارس المحفوظ"
        case 14...:
            return "رفيق الورد"
        case 7...:
            return "صاحب المراجعة"
        case 1...:
            return "بداية الورد"
        default:
            return "هيئ الخطة"
        }
    }

    var todaysQuranRevision: [QuranRubReference] {
        quranRevisionAssignment(for: Date())
    }

    var upcomingQuranRevisionAssignments: [QuranDailyAssignment] {
        quranRevisionAssignments(days: 6)
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

    func remainingPrayerDebt(for prayer: PrayerCompensationType) -> Int {
        let debt = compensationProgress.prayerDebtCounts[prayer.rawValue] ?? 0
        let compensated = compensationProgress.compensatedPrayerCounts[prayer.rawValue] ?? 0
        return max(0, debt - compensated)
    }

    func compensatedPrayerCount(for prayer: PrayerCompensationType) -> Int {
        compensationProgress.compensatedPrayerCounts[prayer.rawValue] ?? 0
    }

    func prayerDebtCount(for prayer: PrayerCompensationType) -> Int {
        compensationProgress.prayerDebtCounts[prayer.rawValue] ?? 0
    }

    func updateCompensationTargets(prayerCounts: [PrayerCompensationType: Int], fastingDays: Int) {
        for prayer in PrayerCompensationType.allCases {
            let debt = max(0, prayerCounts[prayer] ?? 0)
            compensationProgress.prayerDebtCounts[prayer.rawValue] = debt
            let compensated = compensationProgress.compensatedPrayerCounts[prayer.rawValue] ?? 0
            compensationProgress.compensatedPrayerCounts[prayer.rawValue] = min(compensated, debt)
        }

        compensationProgress.fastingDebtDays = max(0, fastingDays)
        compensationProgress.compensatedFastingDays = min(
            compensationProgress.compensatedFastingDays,
            compensationProgress.fastingDebtDays
        )
        compensationProgress.normalize()
        saveData()
    }

    @discardableResult
    func logCompensatedPrayer(_ prayer: PrayerCompensationType, count: Int = 1, on date: Date = Date()) -> Int {
        let remaining = remainingPrayerDebt(for: prayer)
        let loggedCount = min(max(0, count), remaining)
        guard loggedCount > 0 else { return 0 }

        compensationProgress.compensatedPrayerCounts[prayer.rawValue, default: 0] += loggedCount
        updateCompensationStreak(on: date)
        grantXP(loggedCount * 3)
        awardCompensationBadgesIfNeeded()
        saveData()
        return loggedCount
    }

    @discardableResult
    func logCompensatedFastingDays(_ count: Int = 1, on date: Date = Date()) -> Int {
        let remaining = remainingFastingDebtDays
        let loggedCount = min(max(0, count), remaining)
        guard loggedCount > 0 else { return 0 }

        compensationProgress.compensatedFastingDays += loggedCount
        updateCompensationStreak(on: date)
        grantXP(loggedCount * 12)
        awardCompensationBadgesIfNeeded()
        saveData()
        return loggedCount
    }

    func configureQuranRevisionPlan(juzCount: Int, additionalHizb: Int, additionalRub: Int, dailyGoalRubs: Int) {
        let safeJuz = min(max(0, juzCount), 30)
        let safeHizb = min(max(0, additionalHizb), safeJuz == 30 ? 0 : 1)
        let maxAdditionalRub = safeJuz == 30 && safeHizb == 0 ? 0 : 3
        let safeRub = min(max(0, additionalRub), maxAdditionalRub)
        let totalRubs = min(240, (safeJuz * 8) + (safeHizb * 4) + safeRub)
        let goal = min(max(1, dailyGoalRubs), max(1, totalRubs == 0 ? 1 : totalRubs))

        quranRevisionPlan = QuranRevisionPlan(
            totalMemorizedRubs: totalRubs,
            dailyGoalRubs: goal,
            startDate: Date(),
            completedDates: [],
            lastCompletionDate: nil,
            streak: 0
        )
        saveData()
    }

    func isQuranRevisionCompleted(on date: Date = Date()) -> Bool {
        let dayKey = dateKey(date)
        return quranRevisionPlan.completedDates.contains(dayKey)
    }

    @discardableResult
    func markQuranRevisionCompleted(on date: Date = Date()) -> Bool {
        guard quranRevisionPlan.totalMemorizedRubs > 0 else { return false }
        let dayKey = dateKey(date)
        guard !quranRevisionPlan.completedDates.contains(dayKey) else { return false }

        quranRevisionPlan.completedDates.append(dayKey)
        quranRevisionPlan.completedDates.sort()
        updateQuranRevisionStreak(on: dayKey)
        grantXP(quranRevisionPlan.dailyGoalRubs * 6)
        awardQuranRevisionBadgesIfNeeded()
        saveData()
        return true
    }

    func quranRevisionAssignment(for date: Date) -> [QuranRubReference] {
        let totalRubs = quranRevisionPlan.totalMemorizedRubs
        guard totalRubs > 0 else { return [] }

        let startDate = dateKey(quranRevisionPlan.startDate)
        let day = dateKey(date)
        let elapsedDays = max(0, Calendar.current.dateComponents([.day], from: startDate, to: day).day ?? 0)
        let startIndex = (elapsedDays * quranRevisionPlan.dailyGoalRubs) % totalRubs

        return (0..<quranRevisionPlan.dailyGoalRubs).map { offset in
            let index = ((startIndex + offset) % totalRubs) + 1
            return QuranRubReference(globalRubIndex: index)
        }
    }

    func quranRevisionAssignments(days: Int) -> [QuranDailyAssignment] {
        guard days >= 0 else { return [] }
        let calendar = Calendar.current
        let today = dateKey(Date())

        return (0...days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: today) else { return nil }
            return QuranDailyAssignment(date: date, rubs: quranRevisionAssignment(for: date))
        }
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
                            handleCompletionChange(task: task, wasCompleted: wasCompleted, isNowCompleted: !wasCompleted)
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
                        handleCompletionChange(task: task, wasCompleted: wasCompleted, isNowCompleted: !wasCompleted)
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

    private func handleCompletionChange(task: Task, wasCompleted: Bool, isNowCompleted: Bool) {
        if !wasCompleted && isNowCompleted {
            grantXP(task.score)
            updateLevel()
            updateStreakOnCompletion()
            checkBadges()
        } else if wasCompleted && !isNowCompleted {
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

    private func grantXP(_ amount: Int) {
        guard amount > 0 else { return }
        totalXP += amount
        updateLevel()
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

    private func updateCompensationStreak(on date: Date) {
        let dayKey = dateKey(date)

        if let lastDate = compensationProgress.lastActivityDate {
            if Calendar.current.isDate(lastDate, inSameDayAs: dayKey) {
                return
            }

            let expectedPreviousDay = Calendar.current.date(byAdding: .day, value: -1, to: dayKey)
            if let expectedPreviousDay,
               Calendar.current.isDate(lastDate, inSameDayAs: expectedPreviousDay) {
                compensationProgress.streak += 1
            } else {
                compensationProgress.streak = 1
            }
        } else {
            compensationProgress.streak = 1
        }

        compensationProgress.lastActivityDate = dayKey
    }

    private func updateQuranRevisionStreak(on date: Date) {
        let dayKey = dateKey(date)

        if let lastDate = quranRevisionPlan.lastCompletionDate {
            if Calendar.current.isDate(lastDate, inSameDayAs: dayKey) {
                return
            }

            let expectedPreviousDay = Calendar.current.date(byAdding: .day, value: -1, to: dayKey)
            if let expectedPreviousDay,
               Calendar.current.isDate(lastDate, inSameDayAs: expectedPreviousDay) {
                quranRevisionPlan.streak += 1
            } else {
                quranRevisionPlan.streak = 1
            }
        } else {
            quranRevisionPlan.streak = 1
        }

        quranRevisionPlan.lastCompletionDate = dayKey
    }

    private func awardCompensationBadgesIfNeeded() {
        if compensationProgress.streak == 7 {
            addBadge("ثبات القضاء ٧ أيام")
        }
        if totalCompensatedDebtUnits >= 25 {
            addBadge("منجز ٢٥ قضاء")
        }
        if totalCompensationDebtUnits > 0 && compensationCompletionRate >= 0.5 {
            addBadge("منتصف طريق القضاء")
        }
        if totalCompensationDebtUnits > 0 && totalCompensatedDebtUnits == totalCompensationDebtUnits {
            addBadge("إبراء كامل لما فات")
        }
    }

    private func awardQuranRevisionBadgesIfNeeded() {
        if quranRevisionPlan.streak == 7 {
            addBadge("مراجعة ٧ أيام")
        }
        if quranRevisionPlan.streak == 30 {
            addBadge("مراجعة ٣٠ يومًا")
        }
        let reviewedRubs = quranRevisionPlan.completedDates.count * quranRevisionPlan.dailyGoalRubs
        if reviewedRubs >= 40 {
            addBadge("همة في المراجعة")
        }
        if quranRevisionPlan.totalMemorizedRubs > 0,
           reviewedRubs > 0,
           reviewedRubs % quranRevisionPlan.totalMemorizedRubs == 0 {
            addBadge("ختم دورة مراجعة")
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

    // MARK: - Mutating helpers

    func addTask(name: String, score: Int, categoryName: String) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeCategory = normalizedCategory.isEmpty ? "عام" : normalizedCategory
        let safeScore = max(1, score)

        let newTask = Task(name: safeName, score: safeScore, category: safeCategory, isCompleted: false, level: 1, badge: nil)

        // Try to find an exact category match
        if let catIndex = categories.firstIndex(where: { $0.name == safeCategory }) {
            // Append to the category direct list to avoid misplacing tasks in a random subcategory
            if categories[catIndex].tasks != nil {
                categories[catIndex].tasks?.append(newTask)
            } else {
                categories[catIndex].tasks = [newTask]
            }
        } else {
            // Create a new top-level category with this task
            let newCategory = TaskCategory(name: safeCategory, subCategories: nil, tasks: [newTask])
            categories.append(newCategory)
        }

        // Ensure persistence and update snapshots
        recordProgressSnapshot(for: Date())
        saveData()
    }

    private func dateKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func removeLegacyRamadanData() {
        userDefaults.removeObject(forKey: "ramadanHabitLog")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ramadan_suhoor", "ramadan_iftar"])
    }

    private func pruneCompletedLog() {
        let validTaskIDs = Set(allTasks.map(\.id))
        completedLog = completedLog.filter { validTaskIDs.contains($0.key) }
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
