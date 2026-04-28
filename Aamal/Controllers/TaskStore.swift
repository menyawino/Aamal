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

struct PrayerTaskTarget: Identifiable, Hashable {
    let prayerName: String
    let bundleName: String

    var id: String { prayerName }
}

struct BundleTaskTarget: Identifiable, Hashable {
    let categoryName: String
    let bundleName: String

    var id: String { "\(categoryName)|\(bundleName)" }
}

final class TaskStore: ObservableObject {
    @Published var categories: [TaskCategory]
    @Published private(set) var totalXP: Int = 0
    @Published private(set) var level: Int = 1
    @Published private(set) var streak: Int = 0
    @Published private(set) var badges: [String] = []
    @Published private(set) var scoreLog: [ScoreLogEntry] = []
    @Published private(set) var progressHistory: [ProgressPoint] = []
    @Published private(set) var completedLog: [UUID: Set<Date>] = [:]
    @Published private(set) var tasbihCounts: [String: Int] = [:]
    @Published private(set) var dailyDuaIndex: Int = 0
    @Published private(set) var lastResetDate: Date = Date()
    @Published private(set) var compensationProgress = CompensationProgress()
    @Published private(set) var quranRevisionPlan = QuranRevisionPlan()

    private let xpPerLevel: Int = 20
    private let maxScoreLogEntries: Int = 250
    private let defaultCategories: [TaskCategory]
    private var deletedSeededTaskIDs: Set<UUID> = []
    private var lastCompletionDate: Date?
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var latestPrayerTimings: PrayerTimings?

    private enum Keys {
        static let categories = "categories"
        static let customTasks = "customTasks"
        static let deletedSeededTaskIDs = "deletedSeededTaskIDs"
        static let totalXP = "totalXP"
        static let level = "level"
        static let streak = "streak"
        static let badges = "badges"
        static let scoreLog = "scoreLog"
        static let progressHistory = "progressHistory"
        static let completedLog = "completedLog"
        static let tasbihCounts = "tasbihCounts"
        static let dailyDuaIndex = "dailyDuaIndex"
        static let lastResetDate = "lastResetDate"
        static let lastCompletionDate = "lastCompletionDate"
        static let compensationProgress = "compensationProgress"
        static let quranRevisionPlan = "quranRevisionPlan"
    }

    init(
        categories: [TaskCategory] = [dailyCategory, fridayTasks],
        userDefaults: UserDefaults = .standard,
        requestsNotificationPermission: Bool = true
    ) {
        self.defaultCategories = categories
        self.categories = categories
        self.userDefaults = userDefaults
        loadData()
        removeLegacyRamadanData()
        pruneCompletedLog()
        checkAndResetDaily()
        recordProgressSnapshot(for: Date())
        if requestsNotificationPermission {
            requestNotificationPermission()
        }
    }

    // MARK: - Data Persistence

    private func loadData() {
        if let deletedTaskIDs = userDefaults.stringArray(forKey: Keys.deletedSeededTaskIDs) {
            deletedSeededTaskIDs = Set(deletedTaskIDs.compactMap(UUID.init(uuidString:)))
        }

        let decodedCategories: [TaskCategory]?
        if let categoriesData = userDefaults.data(forKey: Keys.categories),
           let decoded = try? decoder.decode([TaskCategory].self, from: categoriesData) {
            decodedCategories = decoded
        } else {
            decodedCategories = nil
        }

        let decodedCustomTasks: [Task]?
        if let customTasksData = userDefaults.data(forKey: Keys.customTasks),
           let decoded = try? decoder.decode([Task].self, from: customTasksData) {
            decodedCustomTasks = decoded
        } else {
            decodedCustomTasks = nil
        }

        let filteredDefaults = defaultCategoriesApplyingDeletions()

        if let decodedCategories {
            categories = mergeStoredCategories(decodedCategories, into: filteredDefaults)
        } else {
            categories = filteredDefaults
        }

        let recoveredCustomTasks = decodedCustomTasks
            ?? decodedCategories.map { extractCustomTasks(from: $0, comparedTo: defaultCategories) }
            ?? []
        applyCustomTasks(recoveredCustomTasks, to: &categories)

        totalXP = userDefaults.integer(forKey: Keys.totalXP)
        level = userDefaults.integer(forKey: Keys.level)
        if level == 0 { level = 1 }
        streak = userDefaults.integer(forKey: Keys.streak)
        badges = userDefaults.stringArray(forKey: Keys.badges) ?? []
        if let scoreLogData = userDefaults.data(forKey: Keys.scoreLog),
           let decoded = try? decoder.decode([ScoreLogEntry].self, from: scoreLogData) {
            scoreLog = Array(decoded.suffix(maxScoreLogEntries))
        }
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

        applyTodayCompletionFlags()
    }

    private func saveData() {
        if let categoriesData = try? encoder.encode(categories) {
            userDefaults.set(categoriesData, forKey: Keys.categories)
        }

        let customTasks = extractCustomTasks(from: categories, comparedTo: defaultCategories)
        if let customTasksData = try? encoder.encode(customTasks) {
            userDefaults.set(customTasksData, forKey: Keys.customTasks)
        }

        userDefaults.set(deletedSeededTaskIDs.map(\ .uuidString), forKey: Keys.deletedSeededTaskIDs)

        userDefaults.set(totalXP, forKey: Keys.totalXP)
        userDefaults.set(level, forKey: Keys.level)
        userDefaults.set(streak, forKey: Keys.streak)
        userDefaults.set(badges, forKey: Keys.badges)
        if let scoreLogData = try? encoder.encode(scoreLog) {
            userDefaults.set(scoreLogData, forKey: Keys.scoreLog)
        }
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

    var prayerTaskTargets: [PrayerTaskTarget] {
        categories.flatMap { category in
            (category.subCategories ?? []).compactMap { subCategory in
                guard !subCategory.tasks.isEmpty,
                      subCategory.tasks.allSatisfy(isPrayerTask),
                      let prayerName = subCategory.tasks.first?.category
                else {
                    return nil
                }

                return PrayerTaskTarget(prayerName: prayerName, bundleName: subCategory.name)
            }
        }
    }

    var nonPrayerBundleTargets: [BundleTaskTarget] {
        categories.flatMap { category in
            (category.subCategories ?? []).compactMap { subCategory in
                guard !subCategory.tasks.isEmpty,
                      !subCategory.tasks.allSatisfy(isPrayerTask)
                else {
                    return nil
                }

                return BundleTaskTarget(categoryName: category.name, bundleName: subCategory.name)
            }
        }
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

    var quranMarkedWeakRubs: [QuranRubReference] {
        quranRevisionPlan.weakRubIndices.map(QuranRubReference.init(globalRubIndex:))
    }

    var todaysAdaptiveQuranPlan: QuranAdaptiveDailyPlan {
        adaptiveQuranPlan(for: Date())
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
        recordProgressSnapshot(for: Date())
    }

    @discardableResult
    func logCompensatedPrayer(_ prayer: PrayerCompensationType, count: Int = 1, on date: Date = Date()) -> Int {
        let remaining = remainingPrayerDebt(for: prayer)
        let loggedCount = min(max(0, count), remaining)
        guard loggedCount > 0 else { return 0 }

        compensationProgress.compensatedPrayerCounts[prayer.rawValue, default: 0] += loggedCount
        updateCompensationStreak(on: date)
        grantXP(
            loggedCount * 3,
            reason: .compensatedPrayer,
            note: "قضاء \(prayer.arabicName) ×\(loggedCount)",
            on: date
        )
        awardCompensationBadgesIfNeeded()
        recordProgressSnapshot(for: date)
        return loggedCount
    }

    @discardableResult
    func logCompensatedFastingDays(_ count: Int = 1, on date: Date = Date()) -> Int {
        let remaining = remainingFastingDebtDays
        let loggedCount = min(max(0, count), remaining)
        guard loggedCount > 0 else { return 0 }

        compensationProgress.compensatedFastingDays += loggedCount
        updateCompensationStreak(on: date)
        grantXP(
            loggedCount * 12,
            reason: .compensatedFasting,
            note: "قضاء صيام ×\(loggedCount)",
            on: date
        )
        awardCompensationBadgesIfNeeded()
        recordProgressSnapshot(for: date)
        return loggedCount
    }

    func configureQuranRevisionPlan(juzCount: Int, additionalHizb: Int, additionalRub: Int, dailyGoalRubs: Int) {
        let currentCapacities = Dictionary(uniqueKeysWithValues: PrayerCompensationType.allCases.map { prayer in
            (prayer, quranRevisionPlan.capacity(for: prayer))
        })

        configureQuranRevisionPlan(
            juzCount: juzCount,
            additionalHizb: additionalHizb,
            additionalRub: additionalRub,
            dailyGoalRubs: dailyGoalRubs,
            recentWindowRubs: quranRevisionPlan.recentWindowRubs,
            newMemorizationTargetRubs: quranRevisionPlan.newMemorizationTargetRubs,
            prayerCapacities: currentCapacities
        )
    }

    func configureQuranRevisionPlan(
        juzCount: Int,
        additionalHizb: Int,
        additionalRub: Int,
        dailyGoalRubs: Int,
        recentWindowRubs: Int,
        newMemorizationTargetRubs: Int,
        prayerCapacities: [PrayerCompensationType: Int]
    ) {
        let safeJuz = min(max(0, juzCount), 30)
        let safeHizb = min(max(0, additionalHizb), safeJuz == 30 ? 0 : 1)
        let maxAdditionalRub = safeJuz == 30 && safeHizb == 0 ? 0 : 3
        let safeRub = min(max(0, additionalRub), maxAdditionalRub)
        let totalRubs = min(240, (safeJuz * 8) + (safeHizb * 4) + safeRub)
        let goal = min(max(1, dailyGoalRubs), max(1, min(totalRubs == 0 ? 12 : totalRubs, 12)))
        let safeRecentWindow = min(max(1, recentWindowRubs), max(1, min(totalRubs == 0 ? 16 : totalRubs, 16)))
        let safeNewTarget = min(max(0, newMemorizationTargetRubs), totalRubs >= 240 ? 0 : 2)
        let normalizedCapacities = Dictionary(uniqueKeysWithValues: PrayerCompensationType.allCases.map { prayer in
            (prayer.rawValue, max(0, prayerCapacities[prayer] ?? quranRevisionPlan.capacity(for: prayer)))
        })
        let preservesProgress = totalRubs == quranRevisionPlan.totalMemorizedRubs

        quranRevisionPlan = QuranRevisionPlan(
            totalMemorizedRubs: totalRubs,
            dailyGoalRubs: goal,
            recentWindowRubs: safeRecentWindow,
            newMemorizationTargetRubs: safeNewTarget,
            weakRubIndices: quranRevisionPlan.weakRubIndices.filter { $0 <= totalRubs },
            prayerCapacities: normalizedCapacities,
            startDate: preservesProgress ? quranRevisionPlan.startDate : Date(),
            completedDates: preservesProgress ? quranRevisionPlan.completedDates : [],
            lastCompletionDate: preservesProgress ? quranRevisionPlan.lastCompletionDate : nil,
            streak: preservesProgress ? quranRevisionPlan.streak : 0
        )
        recordProgressSnapshot(for: Date())
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
        grantXP(
            quranRevisionPlan.dailyGoalRubs * 6,
            reason: .quranRevisionCompleted,
            note: "إنجاز خطة المراجعة اليومية",
            on: dayKey
        )
        awardQuranRevisionBadgesIfNeeded()
        recordProgressSnapshot(for: dayKey)
        return true
    }

    func isQuranRubMarkedWeak(_ rub: QuranRubReference) -> Bool {
        quranRevisionPlan.weakRubIndices.contains(rub.globalRubIndex)
    }

    @discardableResult
    func markQuranRubWeak(_ rub: QuranRubReference) -> Bool {
        guard (1...quranRevisionPlan.totalMemorizedRubs).contains(rub.globalRubIndex) else { return false }

        quranRevisionPlan.weakRubIndices.removeAll { $0 == rub.globalRubIndex }
        quranRevisionPlan.weakRubIndices.insert(rub.globalRubIndex, at: 0)
        return true
    }

    @discardableResult
    func clearQuranRubWeak(_ rub: QuranRubReference) -> Bool {
        let previousCount = quranRevisionPlan.weakRubIndices.count
        quranRevisionPlan.weakRubIndices.removeAll { $0 == rub.globalRubIndex }
        return quranRevisionPlan.weakRubIndices.count != previousCount
    }

    func quranRevisionAssignment(for date: Date) -> [QuranRubReference] {
        let totalRubs = quranRevisionPlan.totalMemorizedRubs
        guard totalRubs > 0 else { return [] }

        let dayKey = dateKey(date)
        let completedCycleCount = quranRevisionPlan.completedDates.filter { $0 <= dayKey }.count
        let completedCycleOffset = completedCycleCount * quranRevisionPlan.dailyGoalRubs
        let startIndex = completedCycleOffset % totalRubs

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

    private struct QuranSafetyContext {
        let recentPool: [QuranRubReference]
        let recoveryRubs: [QuranRubReference]
        let recentRubs: [QuranRubReference]
        let pastRubs: [QuranRubReference]
        let minimumSafeAyahs: Int
    }

    private struct QuranRecoveryProfile {
        let gapDays: Int
        let completedRecoveryDays: Int
        let currentDayIndex: Int
        let active: Bool
    }

    func adaptiveQuranPlan(for date: Date) -> QuranAdaptiveDailyPlan {
        let dayKey = dateKey(date)
        let emptyAssignments = emptyQuranPrayerAssignments()

        guard quranRevisionPlan.totalMemorizedRubs > 0 else {
            return QuranAdaptiveDailyPlan(
                date: dayKey,
                mode: .normal,
                newMemorization: nil,
                requiredRevision: [],
                prayerAssignments: emptyAssignments,
                guidance: "حدد مقدار المحفوظ أولًا ثم اضبط سعة كل صلاة لتظهر خطة اليوم.",
                safeguards: [],
                newMemorizationAllowed: false
            )
        }

        guard quranRevisionPlan.totalPrayerCapacityAyahs > 0 else {
            return QuranAdaptiveDailyPlan(
                date: dayKey,
                mode: .normal,
                newMemorization: nil,
                requiredRevision: [],
                prayerAssignments: emptyAssignments,
                guidance: "أدخل سعة كل صلاة أولًا ليتم توزيع المراجعة على اليوم.",
                safeguards: [],
                newMemorizationAllowed: false
            )
        }

        let historicalDate = previousDay(before: dayKey)
        let quranCompliance = quranCompletionRate(forLastDays: 7, until: historicalDate)
        let recoveryProfile = quranRecoveryProfile(for: dayKey, historicalCompliance: quranCompliance)

        if recoveryProfile.active {
            return recoveryQuranPlan(for: dayKey, profile: recoveryProfile)
        }

        let safetyContext = normalQuranSafetyContext(for: dayKey, quranCompliance: quranCompliance)
        if quranRevisionPlan.totalPrayerCapacityAyahs < safetyContext.minimumSafeAyahs {
            return reducedSafetyQuranPlan(for: dayKey, context: safetyContext)
        }

        return standardQuranPlan(for: dayKey, quranCompliance: quranCompliance, context: safetyContext)
    }

    func completion(for category: TaskCategory) -> Double {
        completion(for: [category])
    }

    private func quranMissedDays(before date: Date) -> Int {
        let referenceDay = dateKey(quranRevisionPlan.lastCompletionDate ?? quranRevisionPlan.completedDates.last ?? quranRevisionPlan.startDate)
        let days = Calendar.current.dateComponents([.day], from: referenceDay, to: date).day ?? 0
        return max(0, days - 1)
    }

    private func quranCompletionRate(forLastDays days: Int, until date: Date) -> Double {
        guard days > 0 else { return 0 }
        let calendar = Calendar.current
        let dayKey = dateKey(date)
        let completedCount = (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: dayKey)
        }.filter { sampledDate in
            quranRevisionPlan.completedDates.contains(dateKey(sampledDate))
        }.count

        return Double(completedCount) / Double(days)
    }

    private func recoveryRubCount(missedDays: Int, quranCompliance: Double, recentWindow: Int) -> Int {
        guard recentWindow > 0 else { return 0 }

        var count = 0
        if missedDays > 0 {
            count = min(2, missedDays)
        }

        if quranCompliance < 0.45 {
            count = max(count, min(2, recentWindow))
        } else if quranCompliance < 0.7 {
            count = max(count, 1)
        }

        return min(count, recentWindow)
    }

    private func normalQuranSafetyContext(for date: Date, quranCompliance: Double) -> QuranSafetyContext {
        let totalRubs = quranRevisionPlan.totalMemorizedRubs
        let recentWindow = min(quranRevisionPlan.recentWindowRubs, totalRubs)
        let missedDays = quranMissedDays(before: date)
        let recoveryRequired = min(
            recentWindow,
            recoveryRubCount(missedDays: missedDays, quranCompliance: quranCompliance, recentWindow: recentWindow)
        )
        let baseRevisionRubs = min(max(1, quranRevisionPlan.dailyGoalRubs), totalRubs)
        let desiredRecentRubs = min(recentWindow, max(1, min(4, (baseRevisionRubs + 1) / 2)))
        let availablePastRubs = max(0, totalRubs - recentWindow)
        let pastRequired = min(max(0, baseRevisionRubs - desiredRecentRubs), availablePastRubs)
        let recentRequired = min(recentWindow, max(1, baseRevisionRubs - pastRequired))

        let recentPool = memorizedRubPool(start: max(1, totalRubs - recentWindow + 1), end: totalRubs)
        let manualWeakRubs = prioritizedWeakRubs()
        let manualWeakIDs = Set(manualWeakRubs.map(\.globalRubIndex))
        let inferredRecoveryRubs = takeLatestUniqueRubs(
            from: recentPool,
            count: max(0, recoveryRequired - manualWeakRubs.count),
            excluding: manualWeakIDs
        )
        let recoveryRubs = prioritizedUniqueRubs(manualWeakRubs, inferredRecoveryRubs)
        let recoveryIDs = Set(recoveryRubs.map(\.globalRubIndex))
        let recentRubs = takeLatestUniqueRubs(from: recentPool, count: recentRequired, excluding: recoveryIDs)
        let pastRubs = cycledPastRevisionRubs(count: pastRequired, upperBound: availablePastRubs, on: date, excluding: recoveryIDs)

        let minimumSafeAyahs = max(8, estimatedAyahs(for: recoveryRubs) + estimatedAyahs(for: recentRubs) + estimatedAyahs(for: pastRubs))
        return QuranSafetyContext(
            recentPool: recentPool,
            recoveryRubs: recoveryRubs,
            recentRubs: recentRubs,
            pastRubs: pastRubs,
            minimumSafeAyahs: minimumSafeAyahs
        )
    }

    private func standardQuranPlan(for date: Date, quranCompliance: Double, context: QuranSafetyContext) -> QuranAdaptiveDailyPlan {
        let recoveryIDs = Set(context.recoveryRubs.map(\ .globalRubIndex))
        let requiredItems = [
            makePlanSummary(kind: .recovery, rubs: context.recoveryRubs),
            makePlanSummary(kind: .recentRevision, rubs: context.recentRubs),
            makePlanSummary(kind: .pastRevision, rubs: context.pastRubs)
        ].compactMap { $0 }

        let requiredAyahs = requiredItems.reduce(0) { $0 + $1.estimatedAyahs }
        let requestedNewRubs = min(quranRevisionPlan.newMemorizationTargetRubs, max(0, 240 - quranRevisionPlan.totalMemorizedRubs))
        let candidateNewRubs = nextNewMemorizationRubs(after: quranRevisionPlan.totalMemorizedRubs, count: requestedNewRubs)
        let newAllowed = requestedNewRubs > 0
            && quranCompliance >= 0.6
            && quranRevisionPlan.totalPrayerCapacityAyahs >= requiredAyahs + estimatedAyahs(for: candidateNewRubs)

        let remainingCapacity = quranRevisionPlan.totalPrayerCapacityAyahs - requiredAyahs
        let reinforcementExclusions = recoveryIDs.union(context.recentRubs.map(\ .globalRubIndex))
        let reinforcementRubs = remainingCapacity >= 8
            ? takeLatestUniqueRubs(from: context.recentPool, count: 1, excluding: reinforcementExclusions)
            : []

        let slices = pageSlices(for: context.recoveryRubs, kind: .recovery)
            + pageSlices(for: context.recentRubs, kind: .recentRevision)
            + pageSlices(for: context.pastRubs, kind: .pastRevision)
            + pageSlices(for: reinforcementRubs, kind: .reinforcement)

        return QuranAdaptiveDailyPlan(
            date: date,
            mode: .normal,
            newMemorization: newAllowed ? makePlanSummary(kind: .newMemorization, rubs: candidateNewRubs) : nil,
            requiredRevision: requiredItems,
            prayerAssignments: distributeQuranSlices(slices),
            guidance: newAllowed
                ? "ابدأ بالأصعب في الفجر، ثم نفذ بقية التوزيع كما هو موضح."
                : "اليوم موجه للمراجعة فقط حتى تبقى السلامة مرتفعة قبل فتح الجديد من جديد.",
            safeguards: [
                "إذا هبطت المراجعة عن مستوى الأمان يتوقف الجديد تلقائيًا.",
                "المقاطع الضعيفة تُقدَّم دائمًا قبل التوسعة.",
                "لا يتراكم عليك تعويض مفتوح من الأيام السابقة."
            ],
            newMemorizationAllowed: newAllowed
        )
    }

    private func reducedSafetyQuranPlan(for date: Date, context: QuranSafetyContext) -> QuranAdaptiveDailyPlan {
        let activePrayerCapacities = PrayerCompensationType.allCases
            .map { prayer in (prayer, quranRevisionPlan.capacity(for: prayer)) }
            .filter { $0.1 > 0 }

        let availablePastRubs = max(0, quranRevisionPlan.totalMemorizedRubs - min(quranRevisionPlan.recentWindowRubs, quranRevisionPlan.totalMemorizedRubs))
        let oldestPastPool = memorizedRubPool(start: 1, end: availablePastRubs)

        var requiredItems: [QuranPlanSummaryItem] = []
        var slices: [QuranPlanPageSlice] = []
        var capacityCursor = 0

        if !context.recoveryRubs.isEmpty, capacityCursor < activePrayerCapacities.count {
            let quota = activePrayerCapacities[capacityCursor].1
            let recoverySlices = quotaPageSlices(from: context.recoveryRubs, kind: .recovery, totalAyahs: quota, prioritizeLatestPages: true)
            slices.append(contentsOf: recoverySlices)
            if let item = makePlanSummary(
                kind: .recovery,
                slices: recoverySlices,
                quantityOverrideText: "\(quota) آية"
            ) {
                requiredItems.append(item)
            }
            capacityCursor += 1
        }

        if capacityCursor < activePrayerCapacities.count {
            let quota = activePrayerCapacities[capacityCursor].1
            let recentSource = context.recentRubs.isEmpty ? context.recentPool : context.recentRubs
            let recentSlices = quotaPageSlices(from: recentSource, kind: .recentRevision, totalAyahs: quota, prioritizeLatestPages: true)
            slices.append(contentsOf: recentSlices)
            if let item = makePlanSummary(
                kind: .recentRevision,
                slices: recentSlices,
                quantityOverrideText: "\(quota) آية"
            ) {
                requiredItems.append(item)
            }
            capacityCursor += 1
        }

        let remainingPastQuota = activePrayerCapacities.dropFirst(capacityCursor).reduce(0) { $0 + $1.1 }
        if remainingPastQuota > 0 {
            let pastSource = oldestPastPool.isEmpty ? context.pastRubs : oldestPastPool
            let pastSlices = quotaPageSlices(from: pastSource, kind: .pastRevision, totalAyahs: remainingPastQuota)
            slices.append(contentsOf: pastSlices)
            if let item = makePlanSummary(
                kind: .pastRevision,
                slices: pastSlices,
                quantityOverrideText: "\(remainingPastQuota) آية"
            ) {
                requiredItems.append(item)
            }
        }

        return QuranAdaptiveDailyPlan(
            date: date,
            mode: .reducedSafety,
            newMemorization: nil,
            requiredRevision: requiredItems,
            prayerAssignments: distributeQuranSlices(slices),
            guidance: "اليوم محدود بالسعة لا بالتقصير، لذلك تحولت الخطة إلى حد أدنى يحمي المحفوظ بدل أن يرهقك بحمل غير واقعي.",
            safeguards: [
                "لا توجد رسالة لوم أو عقوبة عند انخفاض السعة.",
                "الجديد متوقف اليوم تلقائيًا حتى لا يضعف المحفوظ.",
                "الغد لا يرث تعويضًا متضخمًا؛ العودة تكون تدريجية فقط."
            ],
            newMemorizationAllowed: false
        )
    }

    private func recoveryQuranPlan(for date: Date, profile: QuranRecoveryProfile) -> QuranAdaptiveDailyPlan {
        let totalRubs = quranRevisionPlan.totalMemorizedRubs
        let recentWindow = min(quranRevisionPlan.recentWindowRubs, totalRubs)
        let atRiskPool = memorizedRubPool(start: max(1, totalRubs - 7), end: totalRubs)
        let recentPool = memorizedRubPool(start: max(1, totalRubs - recentWindow + 1), end: totalRubs)
        let pastPool = memorizedRubPool(start: 1, end: max(0, totalRubs - recentWindow))
        let manualWeakRubs = prioritizedWeakRubs()
        let forgottenSource = prioritizedUniqueRubs(manualWeakRubs, atRiskPool)
        let recoveryIDs = Set(forgottenSource.map(\.globalRubIndex))
        let recentSource = recentPool.filter { !recoveryIDs.contains($0.globalRubIndex) }
        let pastSource = (pastPool.isEmpty ? recentSource : pastPool).filter { !recoveryIDs.contains($0.globalRubIndex) }

        let isReentry = profile.currentDayIndex <= 3
        let baseForgottenTarget = 10
        let baseRecentTarget = isReentry ? 10 : 0
        let basePastTarget = isReentry
            ? 32
            : min(80, 40 + max(0, profile.currentDayIndex - 4) * 8)

        var remainingCapacity = quranRevisionPlan.totalPrayerCapacityAyahs
        let forgottenQuota = min(baseForgottenTarget, remainingCapacity)
        remainingCapacity -= forgottenQuota
        let recentQuota = min(baseRecentTarget, remainingCapacity)
        remainingCapacity -= recentQuota
        let pastQuota = min(basePastTarget, remainingCapacity)

        let forgottenSlices = quotaPageSlices(from: forgottenSource, kind: .recovery, totalAyahs: forgottenQuota, prioritizeLatestPages: true)
        let recentSlices = quotaPageSlices(from: recentSource, kind: .recentRevision, totalAyahs: recentQuota, prioritizeLatestPages: true)
        let pastSlices = quotaPageSlices(from: pastSource.isEmpty ? recentSource : pastSource, kind: .pastRevision, totalAyahs: pastQuota)

        var requiredItems: [QuranPlanSummaryItem] = []
        if let forgottenItem = makePlanSummary(
            kind: .recovery,
            slices: forgottenSlices,
            quantityOverrideText: "\(forgottenQuota) آية"
        ) {
            requiredItems.append(forgottenItem)
        }
        if let recentItem = makePlanSummary(
            kind: .recentRevision,
            slices: recentSlices,
            quantityOverrideText: recentQuota > 0 ? "\(recentQuota) آية" : nil
        ) {
            requiredItems.append(recentItem)
        }
        if let pastItem = makePlanSummary(
            kind: .pastRevision,
            slices: pastSlices,
            quantityOverrideText: recoveryPastQuantityText(for: pastQuota)
        ) {
            requiredItems.append(pastItem)
        }

        return QuranAdaptiveDailyPlan(
            date: date,
            mode: isReentry ? .recoveryReentry : .recoveryRestabilization,
            newMemorization: nil,
            requiredRevision: requiredItems,
            prayerAssignments: distributeQuranSlices(forgottenSlices + recentSlices + pastSlices),
            guidance: isReentry
                ? "بعد الانقطاع لا نعود إلى الحجم السابق مباشرة؛ نبدأ بخطة قصيرة تعيد الثقة وتثبت آخر المواضع المتأثرة."
                : "العودة الآن تدريجية: جرعة يومية ثابتة للضعيف مع رفع المراجعة القديمة خطوة بعد خطوة حتى تستقر الخطة من جديد.",
            safeguards: isReentry
                ? [
                    "لا يوجد حمل تعويض ضخم عن الأيام الفائتة.",
                    "الجديد متوقف حتى تعود أيام الثبات المطلوبة.",
                    "لا يُعامل كل المحفوظ كضعيف؛ التركيز فقط على آخر النطاق المتأثر."
                ]
                : [
                    "رفع المراجعة يتم تدريجيًا لا عقابيًا.",
                    "الضعيف يبقى حاضرًا يوميًا بجرعة صغيرة ثابتة.",
                    "الجديد لا يعود إلا بعد سلسلة ثبات واضحة وعدم توسع نطاق الضعف."
                ],
            newMemorizationAllowed: false
        )
    }

    private func quranRecoveryProfile(for date: Date, historicalCompliance: Double) -> QuranRecoveryProfile {
        let lapseThresholdDays = 3
        let unlockConsistencyDays = 7
        let missedDays = quranMissedDays(before: date)

        if missedDays >= lapseThresholdDays {
            return QuranRecoveryProfile(gapDays: missedDays, completedRecoveryDays: 0, currentDayIndex: 1, active: true)
        }

        let calendar = Calendar.current
        let completedBeforeDate = quranRevisionPlan.completedDates.filter { $0 < date }.sorted()
        let completedSet = Set(completedBeforeDate)
        var cursor = previousDay(before: date)
        var runLength = 0

        while completedSet.contains(cursor) {
            runLength += 1
            cursor = previousDay(before: cursor)
        }

        guard runLength > 0 else {
            return QuranRecoveryProfile(gapDays: 0, completedRecoveryDays: 0, currentDayIndex: 0, active: false)
        }

        guard let lastCompleted = completedBeforeDate.last,
              let runStart = calendar.date(byAdding: .day, value: -(runLength - 1), to: lastCompleted) else {
            return QuranRecoveryProfile(gapDays: 0, completedRecoveryDays: 0, currentDayIndex: 0, active: false)
        }

        let anchorBeforeRun = completedBeforeDate.last(where: { $0 < runStart }) ?? quranRevisionPlan.startDate
        let gapDaysBeforeRun = max(0, (calendar.dateComponents([.day], from: anchorBeforeRun, to: runStart).day ?? 0) - 1)
        let recoveryUnlocked = runLength >= unlockConsistencyDays && historicalCompliance >= 0.85
        let active = gapDaysBeforeRun >= lapseThresholdDays && !recoveryUnlocked

        return QuranRecoveryProfile(
            gapDays: gapDaysBeforeRun,
            completedRecoveryDays: runLength,
            currentDayIndex: active ? runLength + 1 : 0,
            active: active
        )
    }

    private func memorizedRubPool(start: Int, end: Int) -> [QuranRubReference] {
        guard start <= end else { return [] }
        return (start...end).map { QuranRubReference(globalRubIndex: $0) }
    }

    private func prioritizedWeakRubs(excluding excluded: Set<Int> = []) -> [QuranRubReference] {
        quranRevisionPlan.weakRubIndices.compactMap { rubIndex in
            guard !excluded.contains(rubIndex), (1...quranRevisionPlan.totalMemorizedRubs).contains(rubIndex) else {
                return nil
            }
            return QuranRubReference(globalRubIndex: rubIndex)
        }
    }

    private func prioritizedUniqueRubs(_ groups: [QuranRubReference]...) -> [QuranRubReference] {
        var seen: Set<Int> = []
        var rubs: [QuranRubReference] = []

        for group in groups {
            for rub in group where !seen.contains(rub.globalRubIndex) {
                seen.insert(rub.globalRubIndex)
                rubs.append(rub)
            }
        }

        return rubs
    }

    private func takeLatestUniqueRubs(
        from pool: [QuranRubReference],
        count: Int,
        excluding excluded: Set<Int> = []
    ) -> [QuranRubReference] {
        guard count > 0 else { return [] }

        var selection: [QuranRubReference] = []
        for rub in pool.reversed() where !excluded.contains(rub.globalRubIndex) {
            selection.append(rub)
            if selection.count == count {
                break
            }
        }

        return selection.sorted { $0.globalRubIndex < $1.globalRubIndex }
    }

    private func takeEarliestUniqueRubs(
        from pool: [QuranRubReference],
        count: Int,
        excluding excluded: Set<Int> = []
    ) -> [QuranRubReference] {
        guard count > 0 else { return [] }

        var selection: [QuranRubReference] = []
        for rub in pool where !excluded.contains(rub.globalRubIndex) {
            selection.append(rub)
            if selection.count == count {
                break
            }
        }

        return selection
    }

    private func cycledPastRevisionRubs(
        count: Int,
        upperBound: Int,
        on date: Date,
        excluding excluded: Set<Int> = []
    ) -> [QuranRubReference] {
        guard count > 0, upperBound > 0 else { return [] }

        let completedCycleCount = quranRevisionPlan.completedDates.filter { $0 < date }.count
        let startIndex = (completedCycleCount * max(1, count)) % upperBound

        var rubs: [QuranRubReference] = []
        let availableCount = max(0, upperBound - excluded.filter { $0 <= upperBound }.count)
        let targetCount = min(count, availableCount)
        var offset = 0
        var visited = 0

        while rubs.count < targetCount && visited < upperBound {
            let index = ((startIndex + offset) % upperBound) + 1
            if !excluded.contains(index) {
                rubs.append(QuranRubReference(globalRubIndex: index))
            }
            offset += 1
            visited += 1
        }

        return rubs
    }

    private func nextNewMemorizationRubs(after totalMemorizedRubs: Int, count: Int) -> [QuranRubReference] {
        guard count > 0 else { return [] }
        let availableCount = min(count, max(0, 240 - totalMemorizedRubs))
        guard availableCount > 0 else { return [] }

        return (1...availableCount).map { offset in
            QuranRubReference(globalRubIndex: totalMemorizedRubs + offset)
        }
    }

    private func makePlanSummary(kind: QuranPlanSegmentKind, rubs: [QuranRubReference]) -> QuranPlanSummaryItem? {
        guard !rubs.isEmpty else { return nil }
        return QuranPlanSummaryItem(kind: kind, rubs: rubs, estimatedAyahs: estimatedAyahs(for: rubs))
    }

    private func makePlanSummary(
        kind: QuranPlanSegmentKind,
        slices: [QuranPlanPageSlice],
        quantityOverrideText: String? = nil
    ) -> QuranPlanSummaryItem? {
        guard !slices.isEmpty else { return nil }
        return QuranPlanSummaryItem(
            kind: kind,
            rubs: orderedUniqueRubs(from: slices),
            estimatedAyahs: slices.reduce(0) { $0 + $1.estimatedAyahs },
            quantityOverrideText: quantityOverrideText,
            rangeOverrideText: quranSliceRangeText(slices)
        )
    }

    private func estimatedAyahs(for rubs: [QuranRubReference]) -> Int {
        rubs.reduce(0) { partial, rub in
            partial + estimatedAyahs(for: rub)
        }
    }

    private func estimatedAyahs(for rub: QuranRubReference) -> Int {
        guard let metadata = rub.metadata else { return 20 }
        return max(8, ((metadata.endPage - metadata.startPage) + 1) * 8)
    }

    private func pageSlices(for rubs: [QuranRubReference], kind: QuranPlanSegmentKind) -> [QuranPlanPageSlice] {
        rubs.flatMap { rub in
            guard let metadata = rub.metadata else {
                return [
                    QuranPlanPageSlice(
                        kind: kind,
                        rub: rub,
                        startPage: max(1, rub.globalRubIndex),
                        endPage: max(1, rub.globalRubIndex),
                        estimatedAyahs: estimatedAyahs(for: rub)
                    )
                ]
            }

            return Array(metadata.startPage...metadata.endPage).map { page in
                QuranPlanPageSlice(
                    kind: kind,
                    rub: rub,
                    startPage: page,
                    endPage: page,
                    estimatedAyahs: 8
                )
            }
        }
    }

    private func quotaPageSlices(
        from rubs: [QuranRubReference],
        kind: QuranPlanSegmentKind,
        totalAyahs: Int,
        prioritizeLatestPages: Bool = false
    ) -> [QuranPlanPageSlice] {
        guard totalAyahs > 0 else { return [] }

        var pageUnits: [(rub: QuranRubReference, page: Int)] = []
        for rub in rubs {
            if let metadata = rub.metadata {
                for page in metadata.startPage...metadata.endPage {
                    pageUnits.append((rub: rub, page: page))
                }
            } else {
                pageUnits.append((rub: rub, page: max(1, rub.globalRubIndex)))
            }
        }

        let orderedUnits = prioritizeLatestPages ? pageUnits.reversed() : pageUnits
        var remainingAyahs = totalAyahs
        var slices: [QuranPlanPageSlice] = []

        for unit in orderedUnits where remainingAyahs > 0 {
            let ayahQuota = min(8, remainingAyahs)
            slices.append(
                QuranPlanPageSlice(
                    kind: kind,
                    rub: unit.rub,
                    startPage: unit.page,
                    endPage: unit.page,
                    estimatedAyahs: ayahQuota
                )
            )
            remainingAyahs -= ayahQuota
        }

        return prioritizeLatestPages ? slices.reversed() : slices
    }

    private func distributeQuranSlices(_ slices: [QuranPlanPageSlice]) -> [QuranPrayerAssignment] {
        var queue = slices
        var assignments: [QuranPrayerAssignment] = []

        for prayer in PrayerCompensationType.allCases {
            let capacity = quranRevisionPlan.capacity(for: prayer)
            guard capacity > 0 else {
                assignments.append(
                    QuranPrayerAssignment(prayer: prayer, capacityAyahs: 0, assignedAyahs: 0, segments: [])
                )
                continue
            }

            var assignedSegments: [QuranPlanPageSlice] = []
            var assignedAyahs = 0

            while !queue.isEmpty && assignedAyahs < capacity {
                let next = queue.removeFirst()
                let remainingCapacity = capacity - assignedAyahs

                if next.estimatedAyahs <= remainingCapacity {
                    assignedSegments.append(next)
                    assignedAyahs += next.estimatedAyahs
                } else {
                    assignedSegments.append(
                        QuranPlanPageSlice(
                            kind: next.kind,
                            rub: next.rub,
                            startPage: next.startPage,
                            endPage: next.endPage,
                            estimatedAyahs: remainingCapacity
                        )
                    )
                    assignedAyahs += remainingCapacity
                    queue.insert(
                        QuranPlanPageSlice(
                            kind: next.kind,
                            rub: next.rub,
                            startPage: next.startPage,
                            endPage: next.endPage,
                            estimatedAyahs: next.estimatedAyahs - remainingCapacity
                        ),
                        at: 0
                    )
                    break
                }
            }

            assignments.append(
                QuranPrayerAssignment(
                    prayer: prayer,
                    capacityAyahs: capacity,
                    assignedAyahs: assignedAyahs,
                    segments: assignedSegments
                )
            )
        }

        if !queue.isEmpty, var lastAssignment = assignments.popLast() {
            lastAssignment = QuranPrayerAssignment(
                prayer: lastAssignment.prayer,
                capacityAyahs: lastAssignment.capacityAyahs,
                assignedAyahs: lastAssignment.assignedAyahs + queue.reduce(0) { $0 + $1.estimatedAyahs },
                segments: lastAssignment.segments + queue
            )
            assignments.append(lastAssignment)
        }

        return assignments
    }

    private func orderedUniqueRubs(from slices: [QuranPlanPageSlice]) -> [QuranRubReference] {
        var seen: Set<Int> = []
        var rubs: [QuranRubReference] = []

        for slice in slices where !seen.contains(slice.rub.globalRubIndex) {
            seen.insert(slice.rub.globalRubIndex)
            rubs.append(slice.rub)
        }

        return rubs
    }

    private func quranSliceRangeText(_ slices: [QuranPlanPageSlice]) -> String {
        guard let first = slices.first, let last = slices.last else { return "" }
        if first.startPage == last.endPage {
            return "\(first.rub.detailedTitle) • صفحة \(first.startPage)"
        }
        if first.rub == last.rub {
            return "\(first.rub.detailedTitle) • من صفحة \(first.startPage) إلى صفحة \(last.endPage)"
        }
        return "من \(first.rub.detailedTitle) صفحة \(first.startPage) إلى \(last.rub.detailedTitle) صفحة \(last.endPage)"
    }

    private func recoveryPastQuantityText(for ayahs: Int) -> String {
        guard ayahs > 0 else { return "" }
        let pages = Int(ceil(Double(ayahs) / 8.0))
        if pages >= 10 {
            return "نحو نصف جزء"
        }
        if pages >= 6 {
            return "نحو ثلث جزء"
        }
        return "حوالي \(pages) صفحات"
    }

    private func emptyQuranPrayerAssignments() -> [QuranPrayerAssignment] {
        PrayerCompensationType.allCases.map { prayer in
            QuranPrayerAssignment(
                prayer: prayer,
                capacityAyahs: quranRevisionPlan.capacity(for: prayer),
                assignedAyahs: 0,
                segments: []
            )
        }
    }

    private func previousDay(before date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
    }

    func completion(for categories: [TaskCategory], on date: Date = Date()) -> Double {
        let tasks = availableTasks(for: categories, on: date)
        guard !tasks.isEmpty else { return 0 }
        let completed = tasks.filter { isTaskCompleted($0, on: date) }.count
        return Double(completed) / Double(tasks.count)
    }

    func nextUpTasks(limit: Int, on date: Date = Date()) -> [Task] {
        Array(allTasks.filter { isTaskActive($0, on: date) && !isTaskCompleted($0, on: date) }.prefix(limit))
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
            if let storedPoint = progressHistory.first(where: { calendar.isDate($0.date, inSameDayAs: date) }) {
                return ProgressPoint(date: date, value: storedPoint.value)
            }
            return ProgressPoint(date: date, value: insightCompletionValue(on: date))
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
            insightCompletionValue(on: $0) >= minimumDailyCompletion
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

    @discardableResult
    func toggleTask(taskId: UUID, on date: Date = Date()) -> Bool {
        checkAndResetDaily()
        let dayKey = dateKey(date)
        guard let isCompleted = completionState(taskId: taskId, on: dayKey) else {
            return false
        }
        return updateTaskCompletion(taskId: taskId, completed: !isCompleted, on: dayKey)
    }

    @discardableResult
    func logTask(taskId: UUID, on date: Date = Date()) -> Bool {
        checkAndResetDaily()
        return updateTaskCompletion(taskId: taskId, completed: true, on: date)
    }

    func isTaskCompleted(_ task: Task, on date: Date) -> Bool {
        let dayKey = dateKey(date)
        return completedLog[task.id]?.contains(dayKey) ?? false
    }

    func availableTasks(for categories: [TaskCategory], on date: Date) -> [Task] {
        categories.flatMap { tasksForCategory($0) }.filter { isTaskActive($0, on: date) }
    }

    func removeTask(taskId: UUID) {
        checkAndResetDaily()
        let removedTask = findTask(taskId: taskId)
        let completionCount = completedLog[taskId]?.count ?? 0

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
        if let removedTask {
            if seededTaskIDs.contains(removedTask.id) {
                deletedSeededTaskIDs.insert(removedTask.id)
            }

            if completionCount > 0 {
                applyXPDelta(
                    -(completionCount * removedTask.score),
                    reason: .taskRemoved,
                    note: "حذف مهمة \(removedTask.name) بعد \(completionCount) تسجيلات",
                    on: Date(),
                    effectiveDate: Date()
                )
            }
        }
        recomputeTaskStreak()
        rebuildRecentProgressHistory()
        saveData()
        refreshContextualNotifications()
    }

    @discardableResult
    func updateTask(taskId: UUID, name: String, score: Int) -> Bool {
        checkAndResetDaily()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeScore = max(1, score)

        for categoryIndex in categories.indices {
            if var subCategories = categories[categoryIndex].subCategories {
                for subIndex in subCategories.indices {
                    if let taskIndex = subCategories[subIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                        let currentTask = subCategories[subIndex].tasks[taskIndex]
                        let updatedTask = Task(
                            id: currentTask.id,
                            name: safeName,
                            score: safeScore,
                            category: currentTask.category,
                            isCompleted: currentTask.isCompleted,
                            level: currentTask.level,
                            badge: currentTask.badge,
                            availableFrom: currentTask.availableFrom
                        )

                        subCategories[subIndex].tasks[taskIndex] = updatedTask
                        categories[categoryIndex].subCategories = subCategories
                        applyScoreDeltaIfNeeded(oldTask: currentTask, newTask: updatedTask)
                        saveData()
                        refreshContextualNotifications()
                        return true
                    }
                }
            }

            if var tasks = categories[categoryIndex].tasks,
               let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                let currentTask = tasks[taskIndex]
                let updatedTask = Task(
                    id: currentTask.id,
                    name: safeName,
                    score: safeScore,
                    category: currentTask.category,
                    isCompleted: currentTask.isCompleted,
                    level: currentTask.level,
                    badge: currentTask.badge,
                    availableFrom: currentTask.availableFrom
                )

                tasks[taskIndex] = updatedTask
                categories[categoryIndex].tasks = tasks
                applyScoreDeltaIfNeeded(oldTask: currentTask, newTask: updatedTask)
                saveData()
                refreshContextualNotifications()
                return true
            }
        }

        return false
    }

    @discardableResult
    func unlogTask(taskId: UUID, on date: Date = Date()) -> Bool {
        checkAndResetDaily()
        return updateTaskCompletion(taskId: taskId, completed: false, on: date)
    }

    private func updateTaskCompletion(taskId: UUID, completed targetState: Bool, on date: Date) -> Bool {
        let dayKey = dateKey(date)
        let isToday = Calendar.current.isDateInToday(dayKey)
        for categoryIndex in categories.indices {
            if var subCategories = categories[categoryIndex].subCategories {
                for subIndex in subCategories.indices {
                    if let taskIndex = subCategories[subIndex].tasks.firstIndex(where: { $0.id == taskId }) {
                        let task = subCategories[subIndex].tasks[taskIndex]
                        let wasCompleted = isTaskCompleted(task, on: dayKey)
                        guard wasCompleted != targetState else { return false }

                        setCompletion(taskId: taskId, completed: targetState, on: dayKey)

                        if isToday {
                            subCategories[subIndex].tasks[taskIndex].isCompleted = targetState
                        }
                        categories[categoryIndex].subCategories = subCategories

                        handleCompletionChange(task: task, wasCompleted: wasCompleted, isNowCompleted: targetState, on: dayKey)
                        refreshContextualNotifications()
                        return true
                    }
                }
            }

            if var tasks = categories[categoryIndex].tasks {
                if let taskIndex = tasks.firstIndex(where: { $0.id == taskId }) {
                    let task = tasks[taskIndex]
                    let wasCompleted = isTaskCompleted(task, on: dayKey)
                    guard wasCompleted != targetState else { return false }

                    setCompletion(taskId: taskId, completed: targetState, on: dayKey)
                    if isToday {
                        tasks[taskIndex].isCompleted = targetState
                    }
                    categories[categoryIndex].tasks = tasks

                    handleCompletionChange(task: task, wasCompleted: wasCompleted, isNowCompleted: targetState, on: dayKey)
                    refreshContextualNotifications()
                    return true
                }
            }
        }
        return false
    }

    private func completionState(taskId: UUID, on date: Date) -> Bool? {
        for category in categories {
            if let subCategories = category.subCategories {
                for subCategory in subCategories {
                    if let task = subCategory.tasks.first(where: { $0.id == taskId }) {
                        return isTaskCompleted(task, on: date)
                    }
                }
            }

            if let tasks = category.tasks,
               let task = tasks.first(where: { $0.id == taskId }) {
                return isTaskCompleted(task, on: date)
            }
        }

        return nil
    }

    private func handleCompletionChange(task: Task, wasCompleted: Bool, isNowCompleted: Bool, on date: Date) {
        if !wasCompleted && isNowCompleted {
            grantXP(
                task.score,
                reason: .taskCompleted,
                note: "إنجاز مهمة \(task.name)",
                on: date
            )
            recomputeTaskStreak()
            checkBadges(on: date)
        } else if wasCompleted && !isNowCompleted {
            applyXPDelta(
                -task.score,
                reason: .taskUncompleted,
                note: "إلغاء تسجيل مهمة \(task.name)",
                on: Date(),
                effectiveDate: date
            )
            recomputeTaskStreak()
        }

        recordProgressSnapshot(for: date)
        saveData()
    }

    private func updateLevel() {
        level = max(1, totalXP / xpPerLevel + 1)
    }

    private func recomputeTaskStreak() {
        let distinctDates = Set(completedLog.values.flatMap { $0 })
        guard let latestCompletionDate = distinctDates.max() else {
            streak = 0
            lastCompletionDate = nil
            return
        }

        let calendar = Calendar.current
        var currentDate = latestCompletionDate
        var rebuiltStreak = 0

        while distinctDates.contains(currentDate) {
            rebuiltStreak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) else {
                break
            }
            currentDate = previousDay
        }

        streak = rebuiltStreak
        lastCompletionDate = latestCompletionDate

        if streak >= 7 {
            addBadge("سلسلة ٧ أيام")
        }
        if streak >= 30 {
            addBadge("سلسلة ٣٠ يومًا")
        }
    }

    private func checkBadges(on date: Date) {
        for category in categories {
            if completion(for: [category], on: date) >= 1 {
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

    private func grantXP(
        _ amount: Int,
        reason: ScoreLogReason,
        note: String,
        on date: Date
    ) {
        applyXPDelta(amount, reason: reason, note: note, on: Date(), effectiveDate: date)
    }

    private func applyXPDelta(
        _ delta: Int,
        reason: ScoreLogReason,
        note: String,
        on recordedAt: Date,
        effectiveDate: Date
    ) {
        guard delta != 0 else { return }

        let previousXP = totalXP
        totalXP = max(0, totalXP + delta)

        let appliedDelta = totalXP - previousXP
        guard appliedDelta != 0 else { return }

        updateLevel()
        scoreLog.append(
            ScoreLogEntry(
                recordedAt: recordedAt,
                effectiveDate: dateKey(effectiveDate),
                delta: appliedDelta,
                balanceAfter: totalXP,
                reason: reason,
                note: note
            )
        )

        if scoreLog.count > maxScoreLogEntries {
            scoreLog.removeFirst(scoreLog.count - maxScoreLogEntries)
        }
    }

    func recordProgressSnapshot(for date: Date) {
        let dayKey = dateKey(date)
        let value = insightCompletionValue(on: dayKey)

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
        let series = completionSeries(days: days)
        guard !series.isEmpty else { return 0 }
        let total = series.map(\ .value).reduce(0, +)
        return total / Double(series.count)
    }

    private func insightCompletionValue(on date: Date) -> Double {
        var components: [Double] = [completion(for: categories, on: date)]

        if totalCompensationDebtUnits > 0 {
            components.append(compensationCompletionRate)
        }

        if quranRevisionPlan.totalMemorizedRubs > 0 {
            components.append(quranRevisionCompletionRate(on: date))
        }

        let total = components.reduce(0, +)
        return total / Double(components.count)
    }

    private func quranRevisionCompletionRate(on date: Date) -> Double {
        guard quranRevisionPlan.totalMemorizedRubs > 0 else { return 0 }

        let dayKey = dateKey(date)
        let completedRubs = quranRevisionPlan.completedDates.filter { $0 <= dayKey }.count * quranRevisionPlan.dailyGoalRubs
        let cycleRubs = completedRubs % quranRevisionPlan.totalMemorizedRubs
        return Double(cycleRubs) / Double(quranRevisionPlan.totalMemorizedRubs)
    }

    private func lastNDates(days: Int) -> [Date] {
        guard days > 0 else { return [] }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<days).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today)
        }
    }

    func isTaskActive(_ task: Task, on date: Date) -> Bool {
        if let availableFrom = task.availableFrom,
           dateKey(date) < dateKey(availableFrom) {
            return false
        }

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
        latestPrayerTimings = timings
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: self.notificationIdentifiers())

            let today = Date()
            for slot in timings.slots() {
                let prayerTasks = self.pendingTasks(forPrayerName: slot.arabicName, on: today)
                if !prayerTasks.isEmpty {
                    let prayerBody = self.notificationBody(for: prayerTasks, prefix: "تبقى لك")

                    self.scheduleNotification(
                        id: "prayer_\(slot.apiKey)",
                        title: "مهام \(slot.arabicName)",
                        body: prayerBody,
                        date: slot.date
                    )
                }

                if let wuduTime = Calendar.current.date(byAdding: .minute, value: -10, to: slot.date) {
                    let pendingWuduTasks = self.wuduTasks().filter { !self.isTaskCompleted($0, on: today) }
                    if !pendingWuduTasks.isEmpty {
                        let wuduBody = self.notificationBody(for: pendingWuduTasks, prefix: "قبل \(slot.arabicName)")

                        self.scheduleNotification(
                            id: "wudu_\(slot.apiKey)",
                            title: "تذكير الوضوء",
                            body: wuduBody,
                            date: wuduTime
                        )
                    }
                }
            }

            for reminder in self.timeBlockReminders(for: timings, on: today) {
                self.scheduleNotification(
                    id: reminder.id,
                    title: reminder.title,
                    body: reminder.body,
                    date: reminder.date
                )
            }

        }
    }

    func refreshContextualNotifications() {
        guard let latestPrayerTimings else { return }
        schedulePrayerNotifications(timings: latestPrayerTimings)
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
            "block_morning", "block_midday", "block_evening"]
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

    private func mergeStoredCategories(_ stored: [TaskCategory], into defaults: [TaskCategory]) -> [TaskCategory] {
        var merged = defaults.map { defaultCategory in
            guard let storedCategory = stored.first(where: { $0.name == defaultCategory.name }) else {
                return defaultCategory
            }
            return mergeCategory(defaultCategory, with: storedCategory)
        }

        let defaultNames = Set(defaults.map(\ .name))
        let extraStoredCategories = stored.filter { !defaultNames.contains($0.name) }
        merged.append(contentsOf: extraStoredCategories)
        return merged
    }

    private func mergeCategory(_ base: TaskCategory, with stored: TaskCategory) -> TaskCategory {
        TaskCategory(
            name: base.name,
            subCategories: mergeSubCategories(base.subCategories, with: stored.subCategories),
            tasks: mergeTasks(base.tasks, with: stored.tasks)
        )
    }

    private func mergeSubCategories(_ base: [SubCategory]?, with stored: [SubCategory]?) -> [SubCategory]? {
        guard base != nil || stored != nil else { return nil }

        var merged: [SubCategory] = []
        let baseSubCategories = base ?? []
        let storedSubCategories = stored ?? []

        for baseSubCategory in baseSubCategories {
            if let storedSubCategory = storedSubCategories.first(where: { $0.name == baseSubCategory.name }) {
                merged.append(
                    SubCategory(
                        name: baseSubCategory.name,
                        tasks: mergeTasks(baseSubCategory.tasks, with: storedSubCategory.tasks) ?? []
                    )
                )
            } else {
                merged.append(baseSubCategory)
            }
        }

        let baseNames = Set(baseSubCategories.map(\ .name))
        merged.append(contentsOf: storedSubCategories.filter { !baseNames.contains($0.name) })
        return merged.isEmpty ? nil : merged
    }

    private func mergeTasks(_ base: [Task]?, with stored: [Task]?) -> [Task]? {
        guard base != nil || stored != nil else { return nil }

        var merged: [Task] = []
        var seenTaskIDs = Set<UUID>()

        for task in base ?? [] {
            let storedTask = stored?.first(where: { $0.id == task.id })
            let mergedTask = storedTask ?? task
            if seenTaskIDs.insert(mergedTask.id).inserted {
                merged.append(mergedTask)
            }
        }

        for task in stored ?? [] {
            if seenTaskIDs.insert(task.id).inserted {
                merged.append(task)
            }
        }

        return merged.isEmpty ? nil : merged
    }

    private func extractCustomTasks(from categories: [TaskCategory], comparedTo defaults: [TaskCategory]) -> [Task] {
        let seededTaskIDs = Set(defaults.flatMap(tasksForCategory).map(\ .id))
        return categories
            .flatMap(tasksForCategory)
            .filter { !seededTaskIDs.contains($0.id) }
    }

    private func applyCustomTasks(_ tasks: [Task], to categories: inout [TaskCategory]) {
        guard !tasks.isEmpty else { return }

        for task in tasks {
            guard !categories.flatMap(tasksForCategory).contains(where: { $0.id == task.id }) else {
                continue
            }

            if let categoryIndex = categories.firstIndex(where: { $0.name == task.category }) {
                if categories[categoryIndex].tasks != nil {
                    categories[categoryIndex].tasks?.append(task)
                } else {
                    categories[categoryIndex].tasks = [task]
                }
            } else {
                categories.append(TaskCategory(name: task.category, subCategories: nil, tasks: [task]))
            }
        }
    }

    // MARK: - Mutating helpers

    func addTask(name: String, score: Int, categoryName: String, availableFrom date: Date = Date()) {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeCategory = normalizedCategory.isEmpty ? "عام" : normalizedCategory
        let safeScore = max(1, score)
        let startDate = dateKey(date)

        let newTask = Task(
            name: safeName,
            score: safeScore,
            category: safeCategory,
            isCompleted: false,
            level: 1,
            badge: nil,
            availableFrom: startDate
        )

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
        recordProgressSnapshot(for: startDate)
        saveData()
        refreshContextualNotifications()
    }

    private func findTask(taskId: UUID) -> Task? {
        for category in categories {
            if let subCategories = category.subCategories {
                for subCategory in subCategories {
                    if let task = subCategory.tasks.first(where: { $0.id == taskId }) {
                        return task
                    }
                }
            }

            if let tasks = category.tasks,
               let task = tasks.first(where: { $0.id == taskId }) {
                return task
            }
        }

        return nil
    }

    private func applyTodayCompletionFlags() {
        let today = dateKey(Date())

        for categoryIndex in categories.indices {
            if var subCategories = categories[categoryIndex].subCategories {
                for subIndex in subCategories.indices {
                    for taskIndex in subCategories[subIndex].tasks.indices {
                        let taskId = subCategories[subIndex].tasks[taskIndex].id
                        subCategories[subIndex].tasks[taskIndex].isCompleted = completedLog[taskId]?.contains(today) ?? false
                    }
                }
                categories[categoryIndex].subCategories = subCategories
            }

            if var tasks = categories[categoryIndex].tasks {
                for taskIndex in tasks.indices {
                    let taskId = tasks[taskIndex].id
                    tasks[taskIndex].isCompleted = completedLog[taskId]?.contains(today) ?? false
                }
                categories[categoryIndex].tasks = tasks
            }
        }
    }

    private func applyScoreDeltaIfNeeded(oldTask: Task, newTask: Task) {
        let completionCount = completedLog[oldTask.id]?.count ?? 0
        guard oldTask.score != newTask.score, completionCount > 0 else { return }
        let delta = completionCount * (newTask.score - oldTask.score)
        applyXPDelta(
            delta,
            reason: .taskScoreAdjusted,
            note: "تعديل نقاط مهمة \(newTask.name) بعد \(completionCount) تسجيلات",
            on: Date(),
            effectiveDate: Date()
        )
    }

    private func dateKey(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private var seededTaskIDs: Set<UUID> {
        Set(defaultCategories.flatMap(tasksForCategory).map(\ .id))
    }

    private func defaultCategoriesApplyingDeletions() -> [TaskCategory] {
        defaultCategories.map { category in
            let filteredSubCategories = category.subCategories?.compactMap { subCategory -> SubCategory? in
                let filteredTasks = subCategory.tasks.filter { !deletedSeededTaskIDs.contains($0.id) }
                guard !filteredTasks.isEmpty else { return nil }
                return SubCategory(name: subCategory.name, tasks: filteredTasks)
            }

            let filteredTasks = category.tasks?.filter { !deletedSeededTaskIDs.contains($0.id) }

            return TaskCategory(
                name: category.name,
                subCategories: filteredSubCategories,
                tasks: filteredTasks
            )
        }
    }

    private func rebuildRecentProgressHistory() {
        let calendar = Calendar.current
        let today = dateKey(Date())
        let recentPoints = (0..<30).compactMap { offset -> ProgressPoint? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let dayKey = dateKey(date)
            return ProgressPoint(date: dayKey, value: insightCompletionValue(on: dayKey))
        }
        .sorted { $0.date < $1.date }

        progressHistory = recentPoints
    }

    private func makeCustomTask(name: String, score: Int, category: String, availableFrom date: Date) -> Task {
        Task(
            id: UUID(),
            name: name,
            score: score,
            category: category,
            isCompleted: false,
            level: 1,
            badge: nil,
            availableFrom: date
        )
    }

    private func appendTask(_ task: Task, toCategory categoryName: String) {
        if let categoryIndex = categories.firstIndex(where: { $0.name == categoryName }) {
            if categories[categoryIndex].tasks != nil {
                categories[categoryIndex].tasks?.append(task)
            } else {
                categories[categoryIndex].tasks = [task]
            }
        } else {
            categories.append(TaskCategory(name: categoryName, subCategories: nil, tasks: [task]))
        }
    }

    private func appendTask(_ task: Task, toBundle bundleName: String, inCategory categoryName: String) {
        if let categoryIndex = categories.firstIndex(where: { $0.name == categoryName }) {
            if categories[categoryIndex].subCategories == nil {
                categories[categoryIndex].subCategories = [SubCategory(name: bundleName, tasks: [task])]
                return
            }

            if let subCategoryIndex = categories[categoryIndex].subCategories?.firstIndex(where: { $0.name == bundleName }) {
                categories[categoryIndex].subCategories?[subCategoryIndex].tasks.append(task)
            } else {
                categories[categoryIndex].subCategories?.append(SubCategory(name: bundleName, tasks: [task]))
            }
        } else {
            categories.append(TaskCategory(name: categoryName, subCategories: [SubCategory(name: bundleName, tasks: [task])], tasks: nil))
        }
    }

    private func finalizeTaskStructureMutation() {
        rebuildRecentProgressHistory()
        saveData()
        refreshContextualNotifications()
    }

    private func removeLegacyRamadanData() {
        userDefaults.removeObject(forKey: "ramadanHabitLog")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["ramadan_suhoor", "ramadan_iftar"])
    }

    private func pruneCompletedLog() {
        let validTaskIDs = Set(allTasks.map(\.id))
        completedLog = completedLog.filter { validTaskIDs.contains($0.key) }
    }


    func addTask(name: String, score: Int, toCategory categoryName: String, availableFrom date: Date = Date()) {
        checkAndResetDaily()

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedCategory = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeCategory = normalizedCategory.isEmpty ? "عام" : normalizedCategory
        let safeScore = max(1, score)
        let startDate = dateKey(date)

        let newTask = makeCustomTask(name: safeName, score: safeScore, category: safeCategory, availableFrom: startDate)
        appendTask(newTask, toCategory: safeCategory)
        finalizeTaskStructureMutation()
    }

    func addTask(name: String, score: Int, toPrayer prayerName: String, availableFrom date: Date = Date()) {
        checkAndResetDaily()

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeScore = max(1, score)
        let safePrayer = prayerName.trimmingCharacters(in: .whitespacesAndNewlines)
        let startDate = dateKey(date)
        let bundleName = prayerTaskTargets.first(where: { $0.prayerName == safePrayer })?.bundleName ?? safePrayer
        let newTask = makeCustomTask(name: safeName, score: safeScore, category: safePrayer, availableFrom: startDate)

        appendTask(newTask, toBundle: bundleName, inCategory: "اليومي")
        finalizeTaskStructureMutation()
    }

    func addTask(name: String, score: Int, toAllPrayersAvailableFrom date: Date = Date()) {
        checkAndResetDaily()

        let startDate = dateKey(date)
        for target in prayerTaskTargets {
            let safeName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "مهمة جديدة" : name.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeScore = max(1, score)
            let newTask = makeCustomTask(name: safeName, score: safeScore, category: target.prayerName, availableFrom: startDate)
            appendTask(newTask, toBundle: target.bundleName, inCategory: "اليومي")
        }
        finalizeTaskStructureMutation()
    }

    func addTask(name: String, score: Int, toBundle bundleName: String, inCategory categoryName: String, availableFrom date: Date = Date()) {
        checkAndResetDaily()

        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeName = normalizedName.isEmpty ? "مهمة جديدة" : normalizedName
        let safeScore = max(1, score)
        let safeBundleName = bundleName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeCategoryName = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        let startDate = dateKey(date)
        let newTask = makeCustomTask(name: safeName, score: safeScore, category: safeBundleName, availableFrom: startDate)

        appendTask(newTask, toBundle: safeBundleName, inCategory: safeCategoryName)
        finalizeTaskStructureMutation()
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

    private func pendingTasks(forPrayerName prayerName: String, on date: Date) -> [Task] {
        tasks(forPrayerName: prayerName).filter { !isTaskCompleted($0, on: date) }
    }

    private func pendingTasks(forCategories categoryNames: [String], on date: Date) -> [Task] {
        allTasks.filter { task in
            categoryNames.contains(task.category) &&
            isTaskActive(task, on: date) &&
            !isTaskCompleted(task, on: date)
        }
    }

    private func notificationBody(for tasks: [Task], prefix: String) -> String {
        let preview = tasks.prefix(3).map(\ .name)
        let extraCount = max(0, tasks.count - preview.count)
        let names = preview.joined(separator: "، ")

        if extraCount > 0 {
            return "\(prefix) \(tasks.count) مهام: \(names) و\(extraCount) أخرى."
        }

        return "\(prefix) \(tasks.count) مهام: \(names)."
    }

    private func timeBlockReminders(for timings: PrayerTimings, on date: Date) -> [ContextualReminderPlan] {
        let calendar = Calendar.current
        let plans: [ContextualReminderPlan?] = [
            calendar.date(byAdding: .minute, value: 35, to: timings.fajr).flatMap { reminderDate in
                let tasks = pendingTasks(forCategories: ["مهام الصباح"], on: date)
                guard !tasks.isEmpty else { return nil }
                return ContextualReminderPlan(
                    id: "block_morning",
                    title: "دفعة الصباح",
                    body: notificationBody(for: tasks, prefix: "ما زالت أمامك"),
                    date: reminderDate
                )
            },
            calendar.date(byAdding: .minute, value: 75, to: timings.dhuhr).flatMap { reminderDate in
                let tasks = pendingTasks(forCategories: ["مهام القرآن", "مهام الدعاء", "مهام السلوك", "مهام حقوق العباد"], on: date)
                guard !tasks.isEmpty else { return nil }
                return ContextualReminderPlan(
                    id: "block_midday",
                    title: "الورد اليومي",
                    body: notificationBody(for: tasks, prefix: "تبقى في هذا الوقت"),
                    date: reminderDate
                )
            },
            calendar.date(byAdding: .minute, value: 25, to: timings.maghrib).flatMap { reminderDate in
                let tasks = pendingTasks(forCategories: ["مهام المساء"], on: date)
                guard !tasks.isEmpty else { return nil }
                return ContextualReminderPlan(
                    id: "block_evening",
                    title: "دفعة المساء",
                    body: notificationBody(for: tasks, prefix: "لا تنسَ"),
                    date: reminderDate
                )
            }
        ]

        return plans.compactMap { $0 }
    }
}

private struct ContextualReminderPlan {
    let id: String
    let title: String
    let body: String
    let date: Date
}
