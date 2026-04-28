import Foundation

enum ScoreLogReason: String, Codable, Hashable {
    case taskCompleted
    case taskUncompleted
    case taskScoreAdjusted
    case taskRemoved
    case compensatedPrayer
    case compensatedFasting
    case quranRevisionCompleted
}

struct ScoreLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let recordedAt: Date
    let effectiveDate: Date
    let delta: Int
    let balanceAfter: Int
    let reason: ScoreLogReason
    let note: String

    init(
        id: UUID = UUID(),
        recordedAt: Date = Date(),
        effectiveDate: Date,
        delta: Int,
        balanceAfter: Int,
        reason: ScoreLogReason,
        note: String
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.effectiveDate = effectiveDate
        self.delta = delta
        self.balanceAfter = balanceAfter
        self.reason = reason
        self.note = note
    }
}

struct Score {
    var dailyScore: Int
    var weeklyScore: Int
    var monthlyScore: Int
    var streak: Int
    var level: Int
    var badges: [String]

    mutating func updateScores(daily: Int, weekly: Int, monthly: Int) {
        dailyScore = daily
        weeklyScore = weekly
        monthlyScore = monthly
    }

    mutating func updateStreak(isContinuing: Bool) {
        streak = isContinuing ? streak + 1 : 0
    }

    mutating func upgradeLevel() {
        level += 1
    }

    mutating func addBadge(_ badgeName: String) {
        badges.append(badgeName)
    }
}