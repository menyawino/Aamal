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

private func seededTask(_ name: String, score: Int = 1, category: String) -> Task {
    Task(name: name, score: score, category: category, isCompleted: false, level: 1, badge: nil)
}

let dailyCategory = TaskCategory(name: "اليومي", subCategories: [
    SubCategory(name: "مهام الفجر", tasks: [
        seededTask("التبكير", score: 3, category: "الصبح"),
        seededTask("أذكار الأذان", category: "الصبح"),
        seededTask("الدعاء بين الأذانين", category: "الصبح"),
        seededTask("السنة القبلية", category: "الصبح"),
        seededTask("السواك", category: "الصبح"),
        seededTask("الجماعة الأولى", category: "الصبح"),
        seededTask("تكبيرة الإحرام", category: "الصبح"),
        seededTask("الصف الأول", category: "الصبح"),
        seededTask("أذكار بعد الصلاة", category: "الصبح"),
        seededTask("مشاهدة المنة والافلاس", category: "الصبح"),
        seededTask("تدبر اسرار الصلاة", category: "الصبح"),
        seededTask("قضاء الفوائت", score: 2, category: "الصبح")
    ]),
    SubCategory(name: "مهام الصباح", tasks: [
        seededTask("أذكار الصباح", category: "مهام الصباح"),
        seededTask("التهليل 100 مرة", category: "مهام الصباح"),
        seededTask("الجلوس إلى الشروق", category: "مهام الصباح"),
        seededTask("صلاة الضحى", category: "مهام الصباح")
    ]),
    SubCategory(name: "مهام الظهر", tasks: [
        seededTask("التبكير", score: 3, category: "الظهر"),
        seededTask("أذكار الأذان", category: "الظهر"),
        seededTask("الدعاء بين الأذانين", category: "الظهر"),
        seededTask("السنة القبلية", category: "الظهر"),
        seededTask("السواك", category: "الظهر"),
        seededTask("الجماعة الأولى", category: "الظهر"),
        seededTask("تكبيرة الإحرام", category: "الظهر"),
        seededTask("الصف الأول", category: "الظهر"),
        seededTask("أذكار بعد الصلاة", category: "الظهر"),
        seededTask("السنة البعدية", category: "الظهر"),
        seededTask("مشاهدة المنة والافلاس", category: "الظهر"),
        seededTask("تدبر اسرار الصلاة", category: "الظهر"),
        seededTask("قضاء الفوائت", score: 2, category: "الظهر")
    ]),
    SubCategory(name: "مهام العصر", tasks: [
        seededTask("التبكير", score: 3, category: "العصر"),
        seededTask("أذكار الأذان", category: "العصر"),
        seededTask("الدعاء بين الأذانين", category: "العصر"),
        seededTask("السنة القبلية", category: "العصر"),
        seededTask("السواك", category: "العصر"),
        seededTask("الجماعة الأولى", category: "العصر"),
        seededTask("تكبيرة الإحرام", category: "العصر"),
        seededTask("الصف الأول", category: "العصر"),
        seededTask("أذكار بعد الصلاة", category: "العصر"),
        seededTask("مشاهدة المنة والافلاس", category: "العصر"),
        seededTask("تدبر اسرار الصلاة", category: "العصر"),
        seededTask("قضاء الفوائت", score: 2, category: "العصر")
    ]),
    SubCategory(name: "مهام المساء", tasks: [
        seededTask("أذكار المساء", category: "مهام المساء"),
        seededTask("التهليل", category: "مهام المساء"),
        seededTask("ذكر الغروب", category: "مهام المساء")
    ]),
    SubCategory(name: "مهام المغرب", tasks: [
        seededTask("التبكير", score: 3, category: "المغرب"),
        seededTask("أذكار الأذان", category: "المغرب"),
        seededTask("الدعاء بين الأذانين", category: "المغرب"),
        seededTask("السنة القبلية", category: "المغرب"),
        seededTask("السواك", category: "المغرب"),
        seededTask("الجماعة الأولى", category: "المغرب"),
        seededTask("تكبيرة الإحرام", category: "المغرب"),
        seededTask("الصف الأول", category: "المغرب"),
        seededTask("أذكار بعد الصلاة", category: "المغرب"),
        seededTask("السنة البعدية", category: "المغرب"),
        seededTask("مشاهدة المنة والافلاس", category: "المغرب"),
        seededTask("تدبر اسرار الصلاة", category: "المغرب"),
        seededTask("قضاء الفوائت", score: 2, category: "المغرب")
    ]),
    SubCategory(name: "مهام العشاء", tasks: [
        seededTask("التبكير", score: 3, category: "العشاء"),
        seededTask("أذكار الأذان", category: "العشاء"),
        seededTask("الدعاء بين الأذانين", category: "العشاء"),
        seededTask("السنة القبلية", category: "العشاء"),
        seededTask("السواك", category: "العشاء"),
        seededTask("الجماعة الأولى", category: "العشاء"),
        seededTask("تكبيرة الإحرام", category: "العشاء"),
        seededTask("الصف الأول", category: "العشاء"),
        seededTask("أذكار بعد الصلاة", category: "العشاء"),
        seededTask("السنة البعدية", category: "العشاء"),
        seededTask("مشاهدة المنة والافلاس", category: "العشاء"),
        seededTask("تدبر اسرار الصلاة", category: "العشاء"),
        seededTask("قضاء الفوائت", score: 2, category: "العشاء")
    ]),
    SubCategory(name: "مهام الدعاء", tasks: [
        seededTask("للنفس", category: "مهام الدعاء"),
        seededTask("للمشايخ", category: "مهام الدعاء"),
        seededTask("للإخوة", category: "مهام الدعاء"),
        seededTask("للمسلمين", category: "مهام الدعاء")
    ]),
    SubCategory(name: "مهام القرآن", tasks: [
        seededTask("تفسير ربع", score: 2, category: "مهام القرآن"),
        seededTask("تلاوة تدبر جزء", score: 2, category: "مهام القرآن"),
        seededTask("مراجعة ربع في الرواتب", category: "مهام القرآن"),
        seededTask("حفظ وجه", score: 2, category: "مهام القرآن")
    ]),
    SubCategory(name: "الأذكار المقيدة", tasks: [
        seededTask("الاستيقاظ", category: "الأذكار المقيدة"),
        seededTask("الخلاء", category: "الأذكار المقيدة"),
        seededTask("لبس الثوب وخلعه", category: "الأذكار المقيدة"),
        seededTask("الوضوء", category: "الأذكار المقيدة"),
        seededTask("دخول المنزل والخروج", category: "الأذكار المقيدة"),
        seededTask("المشي إلى المسجد", category: "الأذكار المقيدة"),
        seededTask("المسجد (دخول وخروج)", category: "الأذكار المقيدة"),
        seededTask("الأكل والشرب", category: "الأذكار المقيدة"),
        seededTask("الركوب", category: "الأذكار المقيدة"),
        seededTask("النوم", category: "الأذكار المقيدة"),
        seededTask("استغفار في المجالس", category: "الأذكار المقيدة"),
        seededTask("كفارة المجلس", category: "الأذكار المقيدة"),
        seededTask("الاستغفار المطلق", category: "الأذكار المقيدة"),
        seededTask("الصلاة على النبي", category: "الأذكار المقيدة")
    ]),
    SubCategory(name: "مهام حقوق العباد", tasks: [
        seededTask("بر الوالدين", category: "مهام حقوق العباد"),
        seededTask("صلة الرحم (اخوة واعمام)", category: "مهام حقوق العباد"),
        seededTask("أداء الحقوق", category: "مهام حقوق العباد")
    ]),
    SubCategory(name: "مهام السلوك", tasks: [
        seededTask("ترك آفات اللسان", category: "مهام السلوك"),
        seededTask("ترك فضول النظر", category: "مهام السلوك"),
        seededTask("ورد التوكل والافتقار", category: "مهام السلوك"),
        seededTask("ورد المراقبة والمعية", category: "مهام السلوك"),
        seededTask("معالجة القلب", category: "مهام السلوك"),
        seededTask("الدعوة", category: "مهام السلوك"),
        seededTask("مذاكرة العلم الدنيوي", category: "مهام السلوك"),
        seededTask("مذاكرة دروس العلم", score: 5, category: "مهام السلوك"),
        seededTask("التوبة", category: "مهام السلوك"),
        seededTask("المحاسبة", category: "مهام السلوك")
    ])
], tasks: nil)

let fridayTasks = TaskCategory(name: "مهام الجمعة", subCategories: nil, tasks: [
    seededTask("سنن الفطرة", category: "وظائف الجمعة"),
    seededTask("الغسل", category: "وظائف الجمعة"),
    seededTask("لبس أفضل الثياب", category: "وظائف الجمعة"),
    seededTask("الطيب", category: "وظائف الجمعة"),
    seededTask("السواك", category: "وظائف الجمعة"),
    seededTask("التبكير", category: "وظائف الجمعة"),
    seededTask("سورة الكهف", category: "وظائف الجمعة"),
    seededTask("الصلاة على النبى 100 مرة", category: "وظائف الجمعة"),
    seededTask("الدعاء عند صعود الإمام", category: "وظائف الجمعة"),
    seededTask("الدعاء قبل المغرب", category: "وظائف الجمعة")
])

