import Foundation
import Testing
@testable import Aamal

struct AamalTests {

    @Test func taskCompletionAndRollbackAreLogged() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, task) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        #expect(store.scoreLog.isEmpty)

        #expect(store.logTask(taskId: task.id, on: referenceDate))
        #expect(store.totalXP == task.score)
        #expect(store.scoreLog.count == 1)

        let completionEntry = try #require(store.scoreLog.last)
        #expect(completionEntry.delta == task.score)
        #expect(completionEntry.balanceAfter == task.score)
        #expect(completionEntry.reason == .taskCompleted)
        #expect(Calendar.current.isDate(completionEntry.effectiveDate, inSameDayAs: referenceDate))

        #expect(store.unlogTask(taskId: task.id, on: referenceDate))
        #expect(store.totalXP == 0)
        #expect(store.scoreLog.count == 2)

        let rollbackEntry = try #require(store.scoreLog.last)
        #expect(rollbackEntry.delta == -task.score)
        #expect(rollbackEntry.balanceAfter == 0)
        #expect(rollbackEntry.reason == .taskUncompleted)
        #expect(Calendar.current.isDate(rollbackEntry.effectiveDate, inSameDayAs: referenceDate))
    }

    @Test func scoreAdjustmentsAndTaskRemovalAreLogged() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, task) = makeStore(defaults: defaults, taskScore: 4)
        let referenceDate = Self.referenceDate

        #expect(store.logTask(taskId: task.id, on: referenceDate))
        #expect(store.totalXP == 4)

        #expect(store.updateTask(taskId: task.id, name: task.name, score: 7))
        #expect(store.totalXP == 7)

        let adjustmentEntry = try #require(store.scoreLog.last)
        #expect(adjustmentEntry.delta == 3)
        #expect(adjustmentEntry.balanceAfter == 7)
        #expect(adjustmentEntry.reason == .taskScoreAdjusted)

        store.removeTask(taskId: task.id)
        #expect(store.totalXP == 0)

        let removalEntry = try #require(store.scoreLog.last)
        #expect(removalEntry.delta == -7)
        #expect(removalEntry.balanceAfter == 0)
        #expect(removalEntry.reason == .taskRemoved)
    }

    @Test func nonTaskScoreAwardsAreLoggedAndPersisted() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        store.updateCompensationTargets(prayerCounts: [.fajr: 2], fastingDays: 0)
        #expect(store.logCompensatedPrayer(.fajr, count: 1, on: referenceDate) == 1)
        #expect(store.totalXP == 3)
        #expect(store.scoreLog.last?.reason == .compensatedPrayer)

        store.configureQuranRevisionPlan(
            juzCount: 1,
            additionalHizb: 0,
            additionalRub: 0,
            dailyGoalRubs: 1,
            recentWindowRubs: 4,
            newMemorizationTargetRubs: 0,
            prayerCapacities: [.fajr: 8, .dhuhr: 0, .asr: 0, .maghrib: 0, .isha: 0]
        )
        #expect(store.markQuranRevisionCompleted(on: referenceDate))
        #expect(store.totalXP == 9)
        #expect(store.scoreLog.last?.reason == .quranRevisionCompleted)

        let reloadedStore = TaskStore(
            categories: [Self.testCategory(taskScore: 5)],
            userDefaults: defaults,
            requestsNotificationPermission: false
        )
        #expect(reloadedStore.totalXP == 9)
        #expect(reloadedStore.scoreLog.count == 2)
        #expect(reloadedStore.scoreLog.map(\.reason) == [.compensatedPrayer, .quranRevisionCompleted])
    }

    @Test func qiyamRankAndGraceAwareStreakAreCalculated() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let dayOne = qiyamDate(offsetDays: 0)
        let dayThree = qiyamDate(offsetDays: 2)
        let dayFive = qiyamDate(offsetDays: 4)

        store.configureQuranRevisionPlan(
            juzCount: 1,
            additionalHizb: 0,
            additionalRub: 0,
            dailyGoalRubs: 2,
            recentWindowRubs: 4,
            newMemorizationTargetRubs: 0,
            qiyamEnabled: true,
            prayerCapacities: [.fajr: 12, .dhuhr: 12, .asr: 12, .maghrib: 12, .isha: 12]
        )

        #expect(store.logQiyamSession(from: qiyamAyah(2, 1), to: qiyamAyah(2, 121), on: dayOne))
        var plan = store.adaptiveQuranPlan(for: dayOne)
        #expect(plan.qiyamInsight.rank == .qanit)
        #expect(plan.qiyamInsight.streak == 1)

        #expect(store.logQiyamSession(from: qiyamAyah(2, 121), to: qiyamAyah(2, 141), on: dayThree))
        plan = store.adaptiveQuranPlan(for: dayThree)
        #expect(plan.qiyamInsight.rank == .preservedConnection)
        #expect(plan.qiyamInsight.streak == 2)

        let brokenPlan = store.adaptiveQuranPlan(for: dayFive)
        #expect(brokenPlan.qiyamInsight.streak == 0)
    }

    @Test func qiyamReducesRequiredRevisionLoad() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        store.configureQuranRevisionPlan(
            juzCount: 2,
            additionalHizb: 0,
            additionalRub: 0,
            dailyGoalRubs: 4,
            recentWindowRubs: 8,
            newMemorizationTargetRubs: 0,
            qiyamEnabled: true,
            prayerCapacities: [.fajr: 20, .dhuhr: 20, .asr: 20, .maghrib: 20, .isha: 20]
        )

        let baselinePlan = store.adaptiveQuranPlan(for: referenceDate)
        let baselineAyahs = baselinePlan.requiredRevision.reduce(0) { $0 + $1.estimatedAyahs }
        #expect(baselineAyahs > 0)

        #expect(store.logQiyamSession(from: qiyamAyah(2, 1), to: qiyamAyah(2, 151), on: referenceDate))

        let adjustedPlan = store.adaptiveQuranPlan(for: referenceDate)
        let adjustedAyahs = adjustedPlan.requiredRevision.reduce(0) { $0 + $1.estimatedAyahs }
        #expect(adjustedPlan.qiyamInsight.rank == .qanit)
        #expect(adjustedPlan.qiyamInsight.reducedAyahs > 0)
        #expect(adjustedAyahs < baselineAyahs)
    }

    @Test func qiyamProtectsReducedSafetyDay() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        store.configureQuranRevisionPlan(
            juzCount: 2,
            additionalHizb: 0,
            additionalRub: 0,
            dailyGoalRubs: 4,
            recentWindowRubs: 8,
            newMemorizationTargetRubs: 0,
            qiyamEnabled: true,
            prayerCapacities: [.fajr: 10, .dhuhr: 0, .asr: 0, .maghrib: 0, .isha: 0]
        )

        #expect(store.logQiyamSession(from: qiyamAyah(2, 1), to: qiyamAyah(2, 61), on: referenceDate))

        let plan = store.adaptiveQuranPlan(for: referenceDate)
        #expect(plan.mode == .reducedSafety)
        #expect(plan.qiyamInsight.connectionProtectedToday)
        #expect(plan.qiyamInsight.message.contains("حفظ اتصالك بالقرآن اليوم"))
    }

    @Test func qiyamStopPointLoggingCalculatesAndPersistsRange() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let dayOne = qiyamDate(offsetDays: 0)
        let dayTwo = qiyamDate(offsetDays: 1)

        store.configureQuranRevisionPlan(
            juzCount: 1,
            additionalHizb: 0,
            additionalRub: 0,
            dailyGoalRubs: 2,
            recentWindowRubs: 4,
            newMemorizationTargetRubs: 0,
            qiyamEnabled: true,
            prayerCapacities: [.fajr: 12, .dhuhr: 12, .asr: 12, .maghrib: 12, .isha: 12]
        )

        #expect(store.logQiyamSession(from: qiyamAyah(2, 1), to: qiyamAyah(2, 31), on: dayOne))

        let savedSession = try #require(store.qiyamSession(on: dayOne))
        #expect(savedSession.ayatCount == 30)
        #expect(savedSession.startAyah == qiyamAyah(2, 1))
        #expect(savedSession.endAyah == qiyamAyah(2, 31))
        #expect(store.qiyamLoggingStartReference(on: dayTwo) == qiyamAyah(2, 31))

        let reloadedStore = TaskStore(
            categories: [Self.testCategory(taskScore: 5)],
            userDefaults: defaults,
            requestsNotificationPermission: false
        )
        let reloadedSession = try #require(reloadedStore.qiyamSession(on: dayOne))
        #expect(reloadedSession.ayatCount == 30)
        #expect(reloadedSession.startAyah == qiyamAyah(2, 1))
        #expect(reloadedSession.endAyah == qiyamAyah(2, 31))
    }

    @Test func quranStrengthDecaysAndRecoversWithSpacedReview() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let dayZero = qiyamDate(offsetDays: 0)
        let dayOne = qiyamDate(offsetDays: 1)
        let daySix = qiyamDate(offsetDays: 6)
        let daySeven = qiyamDate(offsetDays: 7)
        let dayEight = qiyamDate(offsetDays: 8)

        store.configureQuranRevisionPlan(
            juzCount: 0,
            additionalHizb: 0,
            additionalRub: 1,
            dailyGoalRubs: 1,
            recentWindowRubs: 1,
            newMemorizationTargetRubs: 0,
            prayerCapacities: [.fajr: 8, .dhuhr: 8, .asr: 0, .maghrib: 0, .isha: 0]
        )

        #expect(store.markQuranRevisionCompleted(on: dayZero))

        let afterFirstReview = try #require(store.quranStrengthComparison(on: dayOne).today.sample(for: 1))
        let decayed = try #require(store.quranStrengthComparison(on: daySix).today.sample(for: 1))
        #expect(decayed.score < afterFirstReview.score)

        #expect(store.markQuranRevisionCompleted(on: daySeven))

        let recovered = try #require(store.quranStrengthComparison(on: dayEight).today.sample(for: 1))
        #expect(recovered.score > decayed.score)
        #expect(recovered.stabilityDays > decayed.stabilityDays)
    }

    @Test func quranStrengthComparisonShowsWeekOverWeekStateAndManualWeakReason() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let dayZero = qiyamDate(offsetDays: 0)
        let daySeven = qiyamDate(offsetDays: 7)
        let dayEight = qiyamDate(offsetDays: 8)

        store.configureQuranRevisionPlan(
            juzCount: 0,
            additionalHizb: 0,
            additionalRub: 1,
            dailyGoalRubs: 1,
            recentWindowRubs: 1,
            newMemorizationTargetRubs: 0,
            prayerCapacities: [.fajr: 8, .dhuhr: 8, .asr: 0, .maghrib: 0, .isha: 0]
        )

        #expect(store.markQuranRevisionCompleted(on: dayZero))
        #expect(store.markQuranRevisionCompleted(on: daySeven))
        #expect(store.markQuranRubWeak(QuranRubReference(globalRubIndex: 1)))

        let comparison = store.quranStrengthComparison(on: dayEight)
        let today = try #require(comparison.today.sample(for: 1))
        let lastWeek = try #require(comparison.lastWeek.sample(for: 1))

        #expect(today.reviewCount == 2)
        #expect(lastWeek.reviewCount == 1)
        #expect(today.stabilityDays > lastWeek.stabilityDays)
        #expect(today.weaknessReason == .manualWeak)
    }

    @Test func qiyamRangeStrengthensOnlyTheAffectedRubs() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let dayZero = qiyamDate(offsetDays: 0)
        let daySix = qiyamDate(offsetDays: 6)
        let daySeven = qiyamDate(offsetDays: 7)

        store.configureQuranRevisionPlan(
            juzCount: 0,
            additionalHizb: 0,
            additionalRub: 2,
            dailyGoalRubs: 1,
            recentWindowRubs: 2,
            newMemorizationTargetRubs: 0,
            qiyamEnabled: true,
            prayerCapacities: [.fajr: 8, .dhuhr: 8, .asr: 0, .maghrib: 0, .isha: 0]
        )

        #expect(store.markQuranRevisionCompleted(on: dayZero))
        #expect(store.logQiyamSession(from: qiyamAyah(2, 1), to: qiyamAyah(2, 31), on: daySix))

        let comparison = store.quranStrengthComparison(on: daySeven)
        let rubOne = try #require(comparison.today.sample(for: 1))
        let rubTwo = try #require(comparison.today.sample(for: 2))

        #expect(rubOne.reviewCount > rubTwo.reviewCount)
        #expect(rubOne.lastReviewDate == daySix)
        #expect(rubOne.score > rubTwo.score)
    }

    @Test func manualQuranStrengthOverrideChangesSnapshot() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        store.configureQuranRevisionPlan(
            juzCount: 0,
            additionalHizb: 0,
            additionalRub: 1,
            dailyGoalRubs: 1,
            recentWindowRubs: 1,
            newMemorizationTargetRubs: 0,
            prayerCapacities: [.fajr: 8, .dhuhr: 8, .asr: 0, .maghrib: 0, .isha: 0]
        )

        let rub = QuranRubReference(globalRubIndex: 1)
        #expect(store.setQuranManualStrength(82, for: rub))

        let sample = try #require(store.quranStrengthComparison(on: referenceDate).today.sample(for: 1))
        #expect(Int(sample.score.rounded()) == 82)
        #expect(sample.manualOverrideScore == 82)
        #expect(sample.weaknessReason == .manualStrengthOverride)
    }

    @Test func quranPrayerLoggingCompletesDayWhenAllActivePrayersAreLogged() throws {
        let (defaults, suiteName) = try makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let (store, _) = makeStore(defaults: defaults)
        let referenceDate = Self.referenceDate

        store.configureQuranRevisionPlan(
            juzCount: 0,
            additionalHizb: 0,
            additionalRub: 1,
            dailyGoalRubs: 1,
            recentWindowRubs: 1,
            newMemorizationTargetRubs: 0,
            prayerCapacities: [.fajr: 8, .dhuhr: 8, .asr: 0, .maghrib: 0, .isha: 0]
        )

        #expect(store.markQuranPrayerCompleted(.fajr, on: referenceDate))
        #expect(store.isQuranPrayerCompleted(.fajr, on: referenceDate))
        #expect(store.markQuranPrayerCompleted(.dhuhr, on: referenceDate))
        #expect(store.isQuranRevisionCompleted(on: referenceDate))
    }

    private static let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

    private func qiyamDate(offsetDays: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offsetDays, to: Calendar.current.startOfDay(for: Self.referenceDate)) ?? Self.referenceDate
    }

    private func qiyamAyah(_ surahIndex: Int, _ ayah: Int) -> QuranAyahReference {
        try! #require(QuranAyahCatalog.reference(surahIndex: surahIndex, ayah: ayah))
    }

    private func makeDefaults() throws -> (UserDefaults, String) {
        let suiteName = "AamalTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    private func makeStore(defaults: UserDefaults, taskScore: Int = 5) -> (TaskStore, Task) {
        let category = Self.testCategory(taskScore: taskScore)
        let task = try! #require(category.tasks?.first)
        let store = TaskStore(
            categories: [category],
            userDefaults: defaults,
            requestsNotificationPermission: false
        )
        return (store, task)
    }

    private static func testCategory(taskScore: Int) -> TaskCategory {
        TaskCategory(
            name: "اختبار",
            subCategories: nil,
            tasks: [
                Task(
                    name: "ورد يومي",
                    score: taskScore,
                    category: "اختبار",
                    isCompleted: false,
                    level: 1,
                    badge: nil
                )
            ]
        )
    }

}
