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

    private static let referenceDate = Date(timeIntervalSince1970: 1_720_000_000)

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
