import Foundation

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