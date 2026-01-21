import Foundation

class TaskController {
    private var tasks: [Task] = []

    func addTask(_ task: Task) {
        tasks.append(task)
    }

    func completeTask(_ task: Task) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].toggleCompletion()
            if tasks[index].isCompleted {
                tasks[index].upgradeLevel()
                tasks[index].assignBadge("Star Performer")
            }
        }
    }

    func getCompletedTasks() -> [Task] {
        return tasks.filter { $0.isCompleted }
    }

    func getTasks() -> [Task] {
        return tasks
    }
}