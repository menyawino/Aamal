import Foundation
import CryptoKit

/// Defines the `Task` model with properties for name, score, category, and completion status, along with a method to toggle task completion.
struct Task: Identifiable {
    let id: UUID
    var name: String
    var score: Int
    var category: String
    var isCompleted: Bool
    var level: Int
    var badge: String?

    init(
        id: UUID? = nil,
        name: String,
        score: Int,
        category: String,
        isCompleted: Bool,
        level: Int,
        badge: String?
    ) {
        self.id = id ?? Task.stableID(name: name, category: category, score: score)
        self.name = name
        self.score = score
        self.category = category
        self.isCompleted = isCompleted
        self.level = level
        self.badge = badge
    }

    /// Toggles the completion status of the task.
    mutating func toggleCompletion() {
        isCompleted.toggle()
    }

    /// Upgrades the level of the task.
    mutating func upgradeLevel() {
        level += 1
    }

    /// Assigns a badge to the task.
    mutating func assignBadge(_ badgeName: String) {
        badge = badgeName
    }

    private static func stableID(name: String, category: String, score: Int) -> UUID {
        let base = "\(name)|\(category)|\(score)"
        let digest = SHA256.hash(data: Data(base.utf8))
        let bytes = Array(digest)
        let uuidBytes: uuid_t = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidBytes)
    }
}

struct SubCategory {
    let name: String
    var tasks: [Task]
}

struct TaskCategory {
    let name: String
    var subCategories: [SubCategory]?
    var tasks: [Task]?
}

let dailyCategory = TaskCategory(name: "اليومي", subCategories: [
    SubCategory(name: "الصلوات", tasks: [
        Task(name: "السنة القبلية", score: 2, category: "الصبح", isCompleted: false, level: 1, badge: nil),
        Task(name: "الجماعة الأولى", score: 2, category: "الصبح", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار بعد الصلاة", score: 2, category: "الصبح", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار الصباح", score: 2, category: "الصبح", isCompleted: false, level: 1, badge: nil),
        Task(name: "السنة القبلية (٤ ركعات)", score: 2, category: "الظهر", isCompleted: false, level: 1, badge: nil),
        Task(name: "الجماعة الأولى", score: 2, category: "الظهر", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار بعد الصلاة", score: 2, category: "الظهر", isCompleted: false, level: 1, badge: nil),
        Task(name: "السنة البعدية", score: 2, category: "الظهر", isCompleted: false, level: 1, badge: nil),
        Task(name: "الجماعة الأولى", score: 2, category: "العصر", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار بعد الصلاة", score: 2, category: "العصر", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار المساء", score: 2, category: "العصر", isCompleted: false, level: 1, badge: nil),
        Task(name: "الجماعة الأولى", score: 2, category: "المغرب", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار بعد الصلاة", score: 2, category: "المغرب", isCompleted: false, level: 1, badge: nil),
        Task(name: "السنة البعدية", score: 2, category: "المغرب", isCompleted: false, level: 1, badge: nil),
        Task(name: "الجماعة الأولى", score: 2, category: "العشاء", isCompleted: false, level: 1, badge: nil),
        Task(name: "اذكار بعد الصلاة", score: 2, category: "العشاء", isCompleted: false, level: 1, badge: nil),
        Task(name: "السنة البعدية", score: 2, category: "العشاء", isCompleted: false, level: 1, badge: nil)
    ]),
    SubCategory(name: "الاذكار المقيدة", tasks: [
        Task(name: "الاستيقاظ", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الخلاء", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "لبس الثوب وخلعه", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الوضوء", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "دخول المنزل والخروج", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "المسجد (دخول وخروج)", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "المشي إلى المسجد", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الأكل والشرب", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "الركوب", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "النوم", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "حضور دروس العلم (السبت والخميس)", score: 5, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "مذاكرة دروس العلم", score: 5, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "بر الوالدين", score: 5, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "نية ان تكون هذه النافلة التي يحفظ الله بها بصرك وسمعك وبصرك", score: 1, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil),
        Task(name: "مذاكرة الدراسة أو إتقان العمل الدنيوي (خمس ساعات)", score: 5, category: "الاذكار المقيدة", isCompleted: false, level: 1, badge: nil)
    ])
], tasks: nil)

let quranTasks = TaskCategory(name: "القرآن", subCategories: nil, tasks: [
    Task(name: "حفظ نصف صفحة", score: 2, category: "قرآن", isCompleted: false, level: 1, badge: nil),
    Task(name: "قراءة ستة ارباع", score: 2, category: "قرآن", isCompleted: false, level: 1, badge: nil),
    Task(name: "الصيام (الاثنين والخميس)", score: 5, category: "قرآن", isCompleted: false, level: 1, badge: nil)
])

let fridayTasks = TaskCategory(name: "مهام الجمعة", subCategories: nil, tasks: [
    Task(name: "سنن الفطرة", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "الغسل", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "الطيب", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "السواك", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "التبكير", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "سورة الكهف", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil),
    Task(name: "الصلاة على النبي 100", score: 1, category: "وظائف الجمعة", isCompleted: false, level: 1, badge: nil)
])