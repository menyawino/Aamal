import Foundation

struct Dua: Identifiable, Codable {
    let id: UUID
    let title: String
    let text: String
    let source: String
    let category: String

    init(id: UUID = UUID(), title: String, text: String, source: String, category: String) {
        self.id = id
        self.title = title
        self.text = text
        self.source = source
        self.category = category
    }
}

let dailyDuas: [Dua] = [
    Dua(
        title: "دعاء الاستفتاح اليومي",
        text: "اللهم أعنّي على ذكرك وشكرك وحسن عبادتك",
        source: "صحيح",
        category: "أذكار عامة"
    ),
    Dua(
        title: "دعاء طلب الهداية",
        text: "اللهم اهدني وسددني",
        source: "صحيح مسلم",
        category: "الهداية"
    ),
    Dua(
        title: "دعاء تفريج الهم",
        text: "اللهم إني أعوذ بك من الهم والحزن، والعجز والكسل",
        source: "صحيح البخاري",
        category: "الهموم"
    ),
    Dua(
        title: "دعاء الاستغفار",
        text: "أستغفر الله العظيم الذي لا إله إلا هو الحي القيوم وأتوب إليه",
        source: "أثر صحيح",
        category: "الاستغفار"
    ),
    Dua(
        title: "دعاء الثبات",
        text: "يا مقلب القلوب ثبت قلبي على دينك",
        source: "الترمذي",
        category: "الثبات"
    )
]

let tasbihPhrases: [String] = [
    "سبحان الله",
    "الحمد لله",
    "لا إله إلا الله",
    "الله أكبر",
    "أستغفر الله",
    "الصلاة على النبي ﷺ"
]
