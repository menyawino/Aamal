import Foundation

class ScoreController {
    private var score = Score(dailyScore: 0, weeklyScore: 0, monthlyScore: 0, streak: 0, level: 1, badges: [])

    func updateDailyScore(_ value: Int) {
        score.dailyScore += value
    }

    func updateWeeklyScore(_ value: Int) {
        score.weeklyScore += value
    }

    func updateMonthlyScore(_ value: Int) {
        score.monthlyScore += value
    }

    func resetDailyScore() {
        score.dailyScore = 0
    }

    func resetWeeklyScore() {
        score.weeklyScore = 0
    }

    func resetMonthlyScore() {
        score.monthlyScore = 0
    }

    func updateStreak(isContinuing: Bool) {
        score.updateStreak(isContinuing: isContinuing)
    }

    func calculateDailyPercentage(totalScore: Int) -> Double {
        return (Double(score.dailyScore) / Double(totalScore)) * 100
    }

    func upgradeLevel() {
        score.upgradeLevel()
    }

    func addBadge(_ badgeName: String) {
        score.addBadge(badgeName)
    }

    func getScore() -> Score {
        return score
    }
    
    func calculateDailyPercentage(tasks: [Task]) -> Double {
        let totalScore = tasks.reduce(0) { $0 + $1.score }
        let completedScore = tasks.filter { $0.isCompleted }.reduce(0) { $0 + $1.score }
        return totalScore > 0 ? (Double(completedScore) / Double(totalScore)) * 100 : 0.0
    }
}