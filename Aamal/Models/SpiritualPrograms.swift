import Foundation

enum PrayerCompensationType: String, CaseIterable, Codable, Identifiable {
    case fajr
    case dhuhr
    case asr
    case maghrib
    case isha

    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .fajr:
            return "الفجر"
        case .dhuhr:
            return "الظهر"
        case .asr:
            return "العصر"
        case .maghrib:
            return "المغرب"
        case .isha:
            return "العشاء"
        }
    }

    var systemImage: String {
        switch self {
        case .fajr:
            return "sunrise.fill"
        case .dhuhr:
            return "sun.max.fill"
        case .asr:
            return "sun.haze.fill"
        case .maghrib:
            return "sunset.fill"
        case .isha:
            return "moon.stars.fill"
        }
    }
}

struct CompensationProgress: Codable {
    var prayerDebtCounts: [String: Int]
    var compensatedPrayerCounts: [String: Int]
    var fastingDebtDays: Int
    var compensatedFastingDays: Int
    var lastActivityDate: Date?
    var streak: Int

    init(
        prayerDebtCounts: [String: Int] = [:],
        compensatedPrayerCounts: [String: Int] = [:],
        fastingDebtDays: Int = 0,
        compensatedFastingDays: Int = 0,
        lastActivityDate: Date? = nil,
        streak: Int = 0
    ) {
        self.prayerDebtCounts = prayerDebtCounts
        self.compensatedPrayerCounts = compensatedPrayerCounts
        self.fastingDebtDays = fastingDebtDays
        self.compensatedFastingDays = compensatedFastingDays
        self.lastActivityDate = lastActivityDate
        self.streak = streak
        normalize()
    }

    mutating func normalize() {
        for prayer in PrayerCompensationType.allCases {
            let debt = max(0, prayerDebtCounts[prayer.rawValue] ?? 0)
            prayerDebtCounts[prayer.rawValue] = debt
            compensatedPrayerCounts[prayer.rawValue] = min(max(0, compensatedPrayerCounts[prayer.rawValue] ?? 0), debt)
        }

        fastingDebtDays = max(0, fastingDebtDays)
        compensatedFastingDays = min(max(0, compensatedFastingDays), fastingDebtDays)
        streak = max(0, streak)
    }
}

public struct QuranAyahReference: Codable, Hashable {
    let surahIndex: Int
    let ayah: Int

    var surah: QuranSurahInfo? {
        QuranAyahCatalog.surah(at: surahIndex)
    }

    var surahName: String {
        surah?.name ?? "سورة غير معروفة"
    }

    var title: String {
        "سورة \(surahName) • آية \(ayah)"
    }

    var shortTitle: String {
        "\(surahName) \(ayah)"
    }
}

public struct QuranSurahInfo: Identifiable, Hashable {
    let index: Int
    let name: String
    let ayahCount: Int

    public var id: Int { index }
}

public enum QuranAyahCatalog {
    static let surahs: [QuranSurahInfo] = quranSurahCatalog
    static let totalMushafPages = 604

    static var totalAyahCount: Int {
        surahs.reduce(0) { partial, surah in
            partial + surah.ayahCount
        }
    }

    static func surah(at index: Int) -> QuranSurahInfo? {
        guard (1...surahs.count).contains(index) else { return nil }
        return surahs[index - 1]
    }

    static func reference(surahIndex: Int, ayah: Int) -> QuranAyahReference? {
        guard let surah = surah(at: surahIndex), (1...surah.ayahCount).contains(ayah) else {
            return nil
        }

        return QuranAyahReference(surahIndex: surahIndex, ayah: ayah)
    }

    static func globalAyahIndex(for reference: QuranAyahReference) -> Int? {
        guard let surah = surah(at: reference.surahIndex),
              (1...surah.ayahCount).contains(reference.ayah) else {
            return nil
        }

        let previousAyahs = surahs.prefix(reference.surahIndex - 1).reduce(0) { partial, surah in
            partial + surah.ayahCount
        }
        return previousAyahs + reference.ayah
    }

    static func ayahCount(from start: QuranAyahReference, to end: QuranAyahReference) -> Int? {
        guard let startIndex = globalAyahIndex(for: start),
              let endIndex = globalAyahIndex(for: end),
              endIndex > startIndex else {
            return nil
        }

        return endIndex - startIndex
    }

    static func estimatedPage(for reference: QuranAyahReference) -> Int? {
        guard let globalIndex = globalAyahIndex(for: reference) else { return nil }
        let position = Double(globalIndex) / Double(max(1, totalAyahCount))
        let rawPage = Int(ceil(position * Double(totalMushafPages)))
        return min(max(1, rawPage), totalMushafPages)
    }
}

struct QiyamSession: Identifiable, Codable, Hashable {
    static let estimatedAyahsPerPage = 20

    let date: Date
    let ayatCount: Int
    let startAyah: QuranAyahReference?
    let endAyah: QuranAyahReference?

    init(
        date: Date,
        ayatCount: Int,
        startAyah: QuranAyahReference? = nil,
        endAyah: QuranAyahReference? = nil
    ) {
        self.date = date
        self.ayatCount = ayatCount
        self.startAyah = startAyah
        self.endAyah = endAyah
    }

    var id: Date { date }

    var estimatedPageCount: Int {
        guard ayatCount > 0 else { return 0 }
        return Int(ceil(Double(ayatCount) / Double(Self.estimatedAyahsPerPage)))
    }

    var rangeSummary: String? {
        guard let startAyah, let endAyah else { return nil }
        return "\(startAyah.title) إلى \(endAyah.title)"
    }
}

enum QuranQiyamRank: String, Codable, Hashable {
    case preservedConnection
    case qanit
    case muqantir

    static func rank(for ayatCount: Int) -> QuranQiyamRank? {
        switch ayatCount {
        case 1000...:
            return .muqantir
        case 100...:
            return .qanit
        case 10...:
            return .preservedConnection
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .preservedConnection:
            return "غير من الغافلين"
        case .qanit:
            return "من القانتين"
        case .muqantir:
            return "من المقنطرين"
        }
    }

    var systemImage: String {
        switch self {
        case .preservedConnection:
            return "moon.zzz.fill"
        case .qanit:
            return "sparkles.rectangle.stack.fill"
        case .muqantir:
            return "star.square.on.square.fill"
        }
    }
}

struct QuranQiyamDailyInsight: Hashable {
    let enabled: Bool
    let session: QiyamSession?
    let streak: Int
    let rank: QuranQiyamRank?
    let reductionFraction: Double
    let reducedAyahs: Int
    let connectionProtectedToday: Bool
    let message: String

    var ayatCount: Int {
        session?.ayatCount ?? 0
    }

    var reductionPercentage: Int {
        Int((reductionFraction * 100).rounded())
    }

    var rangeSummary: String? {
        session?.rangeSummary
    }
}

enum QuranStrengthTier: CaseIterable, Hashable {
    case fragile
    case building
    case anchored
    case unmemorized

    var title: String {
        switch self {
        case .fragile:
            return "هش"
        case .building:
            return "قيد التثبيت"
        case .anchored:
            return "راسخ"
        case .unmemorized:
            return "غير داخل في المحفوظ"
        }
    }

    var subtitle: String {
        switch self {
        case .fragile:
            return "الاحتمال الأضعف للاستدعاء الآن ويحتاج تدخلًا سريعًا."
        case .building:
            return "يتحسن، لكن ثباته الزمني ما زال قصيرًا."
        case .anchored:
            return "استدعاؤه وثباته مرتفعان مقارنة ببقية النطاق."
        case .unmemorized:
            return "لم يدخل هذا الربع بعد ضمن مقدار المحفوظ الحالي."
        }
    }
}

enum QuranStrengthWeaknessReason: String, Hashable {
    case manualWeak
    case manualStrengthOverride
    case dueToday
    case overdue
    case lowStability
    case recovering
    case unmemorized
    case steady

    var title: String {
        switch self {
        case .manualWeak:
            return "موسوم يدويًا"
        case .manualStrengthOverride:
            return "درجة مضبوطة يدويًا"
        case .dueToday:
            return "بلغ حد المراجعة اليوم"
        case .overdue:
            return "تراجع بسبب طول الانقطاع"
        case .lowStability:
            return "ما يزال جديدًا على الذاكرة"
        case .recovering:
            return "دخل طور الاسترجاع"
        case .unmemorized:
            return "خارج المحفوظ"
        case .steady:
            return "مستقر الآن"
        }
    }
}

struct QuranRubStrengthSample: Identifiable, Hashable {
    let rub: QuranRubReference
    let score: Double
    let retrievability: Double
    let stabilityDays: Double
    let reviewCount: Int
    let lastReviewDate: Date?
    let tier: QuranStrengthTier
    let weaknessReason: QuranStrengthWeaknessReason
    let weaknessDetail: String
    let isDueToday: Bool
    let isInRecoveryToday: Bool
    let isManuallyWeak: Bool
    let manualOverrideScore: Double?

    var id: Int { rub.globalRubIndex }
}

struct QuranStrengthDistributionSnapshot: Hashable {
    let referenceDate: Date
    let samples: [QuranRubStrengthSample]

    func count(for tier: QuranStrengthTier) -> Int {
        samples.filter { $0.tier == tier }.count
    }

    func sample(for rubIndex: Int) -> QuranRubStrengthSample? {
        samples.first { $0.rub.globalRubIndex == rubIndex }
    }
}

struct QuranStrengthDistributionComparison: Hashable {
    let today: QuranStrengthDistributionSnapshot
    let lastWeek: QuranStrengthDistributionSnapshot

    func delta(for tier: QuranStrengthTier) -> Int {
        today.count(for: tier) - lastWeek.count(for: tier)
    }
}

struct QuranRubStrengthOverride: Codable, Hashable, Identifiable {
    let rubIndex: Int
    var score: Double

    var id: Int { rubIndex }
}

struct QuranPrayerCompletionLog: Codable, Hashable, Identifiable {
    let date: Date
    var prayerRawValues: [String]

    var id: Date { date }
}

struct QuranRevisionPlan: Codable {
    var totalMemorizedRubs: Int
    var dailyGoalRubs: Int
    var recentWindowRubs: Int
    var newMemorizationTargetRubs: Int
    var qiyamEnabled: Bool
    var qiyamSessions: [QiyamSession]
    var weakRubIndices: [Int]
    var manualStrengthOverrides: [QuranRubStrengthOverride]
    var prayerCapacities: [String: Int]
    var prayerCompletionLogs: [QuranPrayerCompletionLog]
    var startDate: Date
    var completedDates: [Date]
    var lastCompletionDate: Date?
    var streak: Int

    private enum CodingKeys: String, CodingKey {
        case totalMemorizedRubs
        case dailyGoalRubs
        case recentWindowRubs
        case newMemorizationTargetRubs
        case qiyamEnabled
        case qiyamSessions
        case weakRubIndices
        case manualStrengthOverrides
        case prayerCapacities
        case prayerCompletionLogs
        case startDate
        case completedDates
        case lastCompletionDate
        case streak
    }

    static let defaultPrayerCapacities: [String: Int] = [
        PrayerCompensationType.fajr.rawValue: 15,
        PrayerCompensationType.dhuhr.rawValue: 20,
        PrayerCompensationType.asr.rawValue: 20,
        PrayerCompensationType.maghrib.rawValue: 15,
        PrayerCompensationType.isha.rawValue: 10
    ]

    init(
        totalMemorizedRubs: Int = 0,
        dailyGoalRubs: Int = 4,
        recentWindowRubs: Int? = nil,
        newMemorizationTargetRubs: Int = 1,
        qiyamEnabled: Bool = true,
        qiyamSessions: [QiyamSession] = [],
        weakRubIndices: [Int] = [],
        manualStrengthOverrides: [QuranRubStrengthOverride] = [],
        prayerCapacities: [String: Int] = QuranRevisionPlan.defaultPrayerCapacities,
        prayerCompletionLogs: [QuranPrayerCompletionLog] = [],
        startDate: Date = Date(),
        completedDates: [Date] = [],
        lastCompletionDate: Date? = nil,
        streak: Int = 0
    ) {
        self.totalMemorizedRubs = totalMemorizedRubs
        self.dailyGoalRubs = dailyGoalRubs
        self.recentWindowRubs = recentWindowRubs ?? Self.defaultRecentWindow(for: totalMemorizedRubs)
        self.newMemorizationTargetRubs = newMemorizationTargetRubs
        self.qiyamEnabled = qiyamEnabled
        self.qiyamSessions = qiyamSessions
        self.weakRubIndices = weakRubIndices
        self.manualStrengthOverrides = manualStrengthOverrides
        self.prayerCapacities = prayerCapacities
        self.prayerCompletionLogs = prayerCompletionLogs
        self.startDate = startDate
        self.completedDates = completedDates
        self.lastCompletionDate = lastCompletionDate
        self.streak = streak
        normalize()
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalMemorizedRubs = try container.decodeIfPresent(Int.self, forKey: .totalMemorizedRubs) ?? 0
        dailyGoalRubs = try container.decodeIfPresent(Int.self, forKey: .dailyGoalRubs) ?? 4
        recentWindowRubs = try container.decodeIfPresent(Int.self, forKey: .recentWindowRubs)
            ?? Self.defaultRecentWindow(for: totalMemorizedRubs)
        newMemorizationTargetRubs = try container.decodeIfPresent(Int.self, forKey: .newMemorizationTargetRubs) ?? 1
        qiyamEnabled = try container.decodeIfPresent(Bool.self, forKey: .qiyamEnabled) ?? true
        qiyamSessions = try container.decodeIfPresent([QiyamSession].self, forKey: .qiyamSessions) ?? []
        weakRubIndices = try container.decodeIfPresent([Int].self, forKey: .weakRubIndices) ?? []
        manualStrengthOverrides = try container.decodeIfPresent([QuranRubStrengthOverride].self, forKey: .manualStrengthOverrides) ?? []
        prayerCapacities = try container.decodeIfPresent([String: Int].self, forKey: .prayerCapacities)
            ?? Self.defaultPrayerCapacities
        prayerCompletionLogs = try container.decodeIfPresent([QuranPrayerCompletionLog].self, forKey: .prayerCompletionLogs) ?? []
        startDate = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Date()
        completedDates = try container.decodeIfPresent([Date].self, forKey: .completedDates) ?? []
        lastCompletionDate = try container.decodeIfPresent(Date.self, forKey: .lastCompletionDate)
        streak = try container.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        normalize()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalMemorizedRubs, forKey: .totalMemorizedRubs)
        try container.encode(dailyGoalRubs, forKey: .dailyGoalRubs)
        try container.encode(recentWindowRubs, forKey: .recentWindowRubs)
        try container.encode(newMemorizationTargetRubs, forKey: .newMemorizationTargetRubs)
        try container.encode(qiyamEnabled, forKey: .qiyamEnabled)
        try container.encode(qiyamSessions, forKey: .qiyamSessions)
        try container.encode(weakRubIndices, forKey: .weakRubIndices)
        try container.encode(manualStrengthOverrides, forKey: .manualStrengthOverrides)
        try container.encode(prayerCapacities, forKey: .prayerCapacities)
        try container.encode(prayerCompletionLogs, forKey: .prayerCompletionLogs)
        try container.encode(startDate, forKey: .startDate)
        try container.encode(completedDates, forKey: .completedDates)
        try container.encodeIfPresent(lastCompletionDate, forKey: .lastCompletionDate)
        try container.encode(streak, forKey: .streak)
    }

    mutating func normalize() {
        totalMemorizedRubs = min(max(0, totalMemorizedRubs), 240)
        dailyGoalRubs = min(max(1, dailyGoalRubs), max(1, min(totalMemorizedRubs == 0 ? 12 : totalMemorizedRubs, 12)))
        recentWindowRubs = min(max(1, recentWindowRubs), max(1, min(totalMemorizedRubs == 0 ? 16 : totalMemorizedRubs, 16)))
        newMemorizationTargetRubs = min(max(0, newMemorizationTargetRubs), totalMemorizedRubs >= 240 ? 0 : 2)
        qiyamSessions = Self.normalizedQiyamSessions(from: qiyamSessions)
        weakRubIndices = Self.normalizedWeakRubIndices(from: weakRubIndices, totalMemorizedRubs: totalMemorizedRubs)
        manualStrengthOverrides = Self.normalizedStrengthOverrides(from: manualStrengthOverrides, totalMemorizedRubs: totalMemorizedRubs)
        prayerCapacities = Self.normalizedPrayerCapacities(from: prayerCapacities)
        prayerCompletionLogs = Self.normalizedPrayerCompletionLogs(from: prayerCompletionLogs)
        completedDates = Array(Set(completedDates.map { Calendar.current.startOfDay(for: $0) })).sorted()
        if let lastCompletionDate {
            self.lastCompletionDate = Calendar.current.startOfDay(for: lastCompletionDate)
        }
        startDate = Calendar.current.startOfDay(for: startDate)
        streak = max(0, streak)
    }

    func capacity(for prayer: PrayerCompensationType) -> Int {
        prayerCapacities[prayer.rawValue] ?? 0
    }

    var totalPrayerCapacityAyahs: Int {
        PrayerCompensationType.allCases.reduce(0) { partial, prayer in
            partial + capacity(for: prayer)
        }
    }

    func qiyamSession(on date: Date) -> QiyamSession? {
        let dayKey = Calendar.current.startOfDay(for: date)
        return qiyamSessions.first { $0.date == dayKey }
    }

    func completedPrayers(on date: Date) -> Set<PrayerCompensationType> {
        let dayKey = Calendar.current.startOfDay(for: date)
        guard let log = prayerCompletionLogs.first(where: { $0.date == dayKey }) else { return [] }
        return Set(log.prayerRawValues.compactMap(PrayerCompensationType.init(rawValue:)))
    }

    private static func defaultRecentWindow(for totalMemorizedRubs: Int) -> Int {
        guard totalMemorizedRubs > 0 else { return 4 }
        return min(max(4, totalMemorizedRubs / 5), min(16, totalMemorizedRubs))
    }

    private static func normalizedPrayerCapacities(from values: [String: Int]) -> [String: Int] {
        var normalized: [String: Int] = [:]
        for prayer in PrayerCompensationType.allCases {
            normalized[prayer.rawValue] = min(max(0, values[prayer.rawValue] ?? defaultPrayerCapacities[prayer.rawValue] ?? 0), 40)
        }
        return normalized
    }

    private static func normalizedQiyamSessions(from values: [QiyamSession]) -> [QiyamSession] {
        var normalizedByDate: [Date: QiyamSession] = [:]

        for session in values {
            let dayKey = Calendar.current.startOfDay(for: session.date)
            guard let normalizedSession = normalizedQiyamSession(session, dayKey: dayKey) else {
                continue
            }
            normalizedByDate[dayKey] = normalizedSession
        }

        return normalizedByDate.keys.sorted().compactMap { date in
            normalizedByDate[date]
        }
    }

    private static func normalizedQiyamSession(_ session: QiyamSession, dayKey: Date) -> QiyamSession? {
        if let startAyah = session.startAyah,
           let endAyah = session.endAyah,
           let computedAyahs = QuranAyahCatalog.ayahCount(from: startAyah, to: endAyah),
           (1...2000).contains(computedAyahs) {
            return QiyamSession(
                date: dayKey,
                ayatCount: computedAyahs,
                startAyah: startAyah,
                endAyah: endAyah
            )
        }

        let ayatCount = min(max(0, session.ayatCount), 2000)
        guard ayatCount > 0 else { return nil }
        return QiyamSession(date: dayKey, ayatCount: ayatCount)
    }

    private static func normalizedWeakRubIndices(from values: [Int], totalMemorizedRubs: Int) -> [Int] {
        guard totalMemorizedRubs > 0 else { return [] }

        var normalized: [Int] = []
        var seen: Set<Int> = []

        for value in values where (1...totalMemorizedRubs).contains(value) && !seen.contains(value) {
            normalized.append(value)
            seen.insert(value)
        }

        return normalized
    }

    private static func normalizedStrengthOverrides(from values: [QuranRubStrengthOverride], totalMemorizedRubs: Int) -> [QuranRubStrengthOverride] {
        guard totalMemorizedRubs > 0 else { return [] }

        var normalized: [QuranRubStrengthOverride] = []
        var seen: Set<Int> = []

        for value in values {
            guard (1...totalMemorizedRubs).contains(value.rubIndex), !seen.contains(value.rubIndex) else {
                continue
            }

            normalized.append(QuranRubStrengthOverride(rubIndex: value.rubIndex, score: min(max(value.score, 0), 100)))
            seen.insert(value.rubIndex)
        }

        return normalized.sorted { $0.rubIndex < $1.rubIndex }
    }

    private static func normalizedPrayerCompletionLogs(from values: [QuranPrayerCompletionLog]) -> [QuranPrayerCompletionLog] {
        var grouped: [Date: Set<String>] = [:]

        for value in values {
            let dayKey = Calendar.current.startOfDay(for: value.date)
            let prayerValues = value.prayerRawValues.filter { PrayerCompensationType(rawValue: $0) != nil }
            grouped[dayKey, default: []].formUnion(prayerValues)
        }

        return grouped.keys.sorted().map { date in
            QuranPrayerCompletionLog(date: date, prayerRawValues: grouped[date, default: []].sorted())
        }
    }
}

enum QuranPlanSegmentKind: String, CaseIterable, Hashable {
    case newMemorization
    case recovery
    case recentRevision
    case pastRevision
    case reinforcement

    var title: String {
        switch self {
        case .newMemorization:
            return "الحفظ الجديد"
        case .recovery:
            return "استرجاع الضعيف"
        case .recentRevision:
            return "مراجعة السبقي"
        case .pastRevision:
            return "مراجعة الماضي"
        case .reinforcement:
            return "تثبيت إضافي"
        }
    }

    var shortTitle: String {
        switch self {
        case .newMemorization:
            return "جديد"
        case .recovery:
            return "استرجاع"
        case .recentRevision:
            return "سبقي"
        case .pastRevision:
            return "ماضٍ"
        case .reinforcement:
            return "تثبيت"
        }
    }

    var systemImage: String {
        switch self {
        case .newMemorization:
            return "book.closed.fill"
        case .recovery:
            return "shield.lefthalf.filled"
        case .recentRevision:
            return "clock.arrow.trianglehead.counterclockwise.rotate.90"
        case .pastRevision:
            return "books.vertical.fill"
        case .reinforcement:
            return "sparkles"
        }
    }
}

enum QuranAdaptiveMode: String, Hashable {
    case normal
    case reducedSafety
    case recoveryReentry
    case recoveryRestabilization

    var statusTitle: String {
        switch self {
        case .normal:
            return "الخطة المعتادة"
        case .reducedSafety:
            return "سعة محدودة مكتشفة"
        case .recoveryReentry:
            return "وضع الاستعادة: إعادة دخول"
        case .recoveryRestabilization:
            return "وضع الاستعادة: إعادة تثبيت"
        }
    }

    var goalTitle: String {
        switch self {
        case .normal:
            return "تنفيذ الخطة الكاملة"
        case .reducedSafety:
            return "منع التراجع"
        case .recoveryReentry:
            return "استعادة الثقة"
        case .recoveryRestabilization:
            return "رفع المراجعة تدريجيًا"
        }
    }

    var systemImage: String {
        switch self {
        case .normal:
            return "checkmark.seal.fill"
        case .reducedSafety:
            return "exclamationmark.triangle.fill"
        case .recoveryReentry:
            return "arrow.counterclockwise.circle.fill"
        case .recoveryRestabilization:
            return "shield.checkered"
        }
    }
}

struct QuranPlanSummaryItem: Identifiable, Hashable {
    let kind: QuranPlanSegmentKind
    let rubs: [QuranRubReference]
    let estimatedAyahs: Int
    let quantityOverrideText: String?
    let rangeOverrideText: String?

    init(
        kind: QuranPlanSegmentKind,
        rubs: [QuranRubReference],
        estimatedAyahs: Int,
        quantityOverrideText: String? = nil,
        rangeOverrideText: String? = nil
    ) {
        self.kind = kind
        self.rubs = rubs
        self.estimatedAyahs = estimatedAyahs
        self.quantityOverrideText = quantityOverrideText
        self.rangeOverrideText = rangeOverrideText
    }

    var id: String {
        "\(kind.rawValue)-\(rubs.map(\ .globalRubIndex).map(String.init).joined(separator: "-"))"
    }

    var quantityText: String {
        if let quantityOverrideText {
            return quantityOverrideText
        }
        guard !rubs.isEmpty else { return "0" }
        if rubs.count % 8 == 0 {
            return "\(rubs.count / 8) جزء"
        }
        if rubs.count % 4 == 0 {
            return "\(rubs.count / 4) حزب"
        }
        if rubs.count == 1 {
            return "ربع واحد"
        }
        return "\(rubs.count) أرباع"
    }

    var rangeText: String {
        if let rangeOverrideText {
            return rangeOverrideText
        }
        guard let first = rubs.first else { return "" }
        guard let last = rubs.last, last != first else {
            return first.detailedTitle
        }
        return "\(first.detailedTitle) إلى \(last.detailedTitle)"
    }
}

struct QuranPlanPageSlice: Identifiable, Hashable {
    let kind: QuranPlanSegmentKind
    let rub: QuranRubReference
    let startPage: Int
    let endPage: Int
    let estimatedAyahs: Int

    var id: String {
        "\(kind.rawValue)-\(rub.globalRubIndex)-\(startPage)-\(endPage)"
    }

    var pageText: String {
        if startPage == endPage {
            return "صفحة \(startPage)"
        }
        return "صفحات \(startPage)-\(endPage)"
    }

    var title: String {
        "\(kind.title): \(pageText)"
    }

    var detailText: String {
        "\(rub.detailedTitle) • \(pageText)"
    }
}

struct QuranPrayerAssignment: Identifiable, Hashable {
    let prayer: PrayerCompensationType
    let capacityAyahs: Int
    let assignedAyahs: Int
    let segments: [QuranPlanPageSlice]

    var id: String { prayer.rawValue }

    var primaryKind: QuranPlanSegmentKind? {
        segments.first?.kind
    }
}

struct QuranAdaptiveDailyPlan: Hashable {
    let date: Date
    let mode: QuranAdaptiveMode
    let newMemorization: QuranPlanSummaryItem?
    let requiredRevision: [QuranPlanSummaryItem]
    let prayerAssignments: [QuranPrayerAssignment]
    let qiyamInsight: QuranQiyamDailyInsight
    let guidance: String
    let safeguards: [String]
    let newMemorizationAllowed: Bool

    var totalAssignedAyahs: Int {
        prayerAssignments.reduce(0) { partial, assignment in
            partial + assignment.assignedAyahs
        }
    }

    var statusTitle: String {
        mode.statusTitle
    }

    var goalTitle: String {
        mode.goalTitle
    }
}

struct QuranRubMetadata: Hashable {
    let startPage: Int
    let endPage: Int
    let startSurah: String
    let endSurah: String

    var pageCount: Int {
        max(1, endPage - startPage + 1)
    }

    var surahSpanText: String {
        if startSurah == endSurah {
            return "من سورة \(startSurah)"
        }
        return "من سورة \(startSurah) إلى سورة \(endSurah)"
    }

    var pageSpanText: String {
        if startPage == endPage {
            return "صفحة \(startPage)"
        }
        return "من صفحة \(startPage) إلى صفحة \(endPage)"
    }

    var spanSummary: String {
        "\(surahSpanText) • \(pageSpanText)"
    }
}

struct QuranRubReference: Identifiable, Hashable {
    let globalRubIndex: Int

    var id: Int { globalRubIndex }

    var juzNumber: Int {
        ((globalRubIndex - 1) / 8) + 1
    }

    var hizbNumberInJuz: Int {
        (((globalRubIndex - 1) % 8) / 4) + 1
    }

    var rubNumberInHizb: Int {
        (((globalRubIndex - 1) % 8) % 4) + 1
    }

    var shortTitle: String {
        "ج\(juzNumber) • ح\(hizbNumberInJuz) • ر\(rubNumberInHizb)"
    }

    var detailedTitle: String {
        "الجزء \(juzNumber) - الحزب \(hizbNumberInJuz) - الربع \(rubNumberInHizb)"
    }

    var metadata: QuranRubMetadata? {
        quranRubMetadataLookup[globalRubIndex]
    }

    var surahSpanText: String {
        metadata?.surahSpanText ?? ""
    }

    var pageSpanText: String {
        metadata?.pageSpanText ?? ""
    }

    var spanSummary: String {
        metadata?.spanSummary ?? ""
    }
}

struct QuranDailyAssignment: Identifiable {
    let date: Date
    let rubs: [QuranRubReference]

    var id: Date { date }
}

private let quranSurahCatalog: [QuranSurahInfo] = [
    QuranSurahInfo(index: 1, name: "الفاتحة", ayahCount: 7),
    QuranSurahInfo(index: 2, name: "البقرة", ayahCount: 286),
    QuranSurahInfo(index: 3, name: "آل عمران", ayahCount: 200),
    QuranSurahInfo(index: 4, name: "النساء", ayahCount: 176),
    QuranSurahInfo(index: 5, name: "المائدة", ayahCount: 120),
    QuranSurahInfo(index: 6, name: "الأنعام", ayahCount: 165),
    QuranSurahInfo(index: 7, name: "الأعراف", ayahCount: 206),
    QuranSurahInfo(index: 8, name: "الأنفال", ayahCount: 75),
    QuranSurahInfo(index: 9, name: "التوبة", ayahCount: 129),
    QuranSurahInfo(index: 10, name: "يونس", ayahCount: 109),
    QuranSurahInfo(index: 11, name: "هود", ayahCount: 123),
    QuranSurahInfo(index: 12, name: "يوسف", ayahCount: 111),
    QuranSurahInfo(index: 13, name: "الرعد", ayahCount: 43),
    QuranSurahInfo(index: 14, name: "إبراهيم", ayahCount: 52),
    QuranSurahInfo(index: 15, name: "الحجر", ayahCount: 99),
    QuranSurahInfo(index: 16, name: "النحل", ayahCount: 128),
    QuranSurahInfo(index: 17, name: "الإسراء", ayahCount: 111),
    QuranSurahInfo(index: 18, name: "الكهف", ayahCount: 110),
    QuranSurahInfo(index: 19, name: "مريم", ayahCount: 98),
    QuranSurahInfo(index: 20, name: "طه", ayahCount: 135),
    QuranSurahInfo(index: 21, name: "الأنبياء", ayahCount: 112),
    QuranSurahInfo(index: 22, name: "الحج", ayahCount: 78),
    QuranSurahInfo(index: 23, name: "المؤمنون", ayahCount: 118),
    QuranSurahInfo(index: 24, name: "النور", ayahCount: 64),
    QuranSurahInfo(index: 25, name: "الفرقان", ayahCount: 77),
    QuranSurahInfo(index: 26, name: "الشعراء", ayahCount: 227),
    QuranSurahInfo(index: 27, name: "النمل", ayahCount: 93),
    QuranSurahInfo(index: 28, name: "القصص", ayahCount: 88),
    QuranSurahInfo(index: 29, name: "العنكبوت", ayahCount: 69),
    QuranSurahInfo(index: 30, name: "الروم", ayahCount: 60),
    QuranSurahInfo(index: 31, name: "لقمان", ayahCount: 34),
    QuranSurahInfo(index: 32, name: "السجدة", ayahCount: 30),
    QuranSurahInfo(index: 33, name: "الأحزاب", ayahCount: 73),
    QuranSurahInfo(index: 34, name: "سبأ", ayahCount: 54),
    QuranSurahInfo(index: 35, name: "فاطر", ayahCount: 45),
    QuranSurahInfo(index: 36, name: "يس", ayahCount: 83),
    QuranSurahInfo(index: 37, name: "الصافات", ayahCount: 182),
    QuranSurahInfo(index: 38, name: "ص", ayahCount: 88),
    QuranSurahInfo(index: 39, name: "الزمر", ayahCount: 75),
    QuranSurahInfo(index: 40, name: "غافر", ayahCount: 85),
    QuranSurahInfo(index: 41, name: "فصلت", ayahCount: 54),
    QuranSurahInfo(index: 42, name: "الشورى", ayahCount: 53),
    QuranSurahInfo(index: 43, name: "الزخرف", ayahCount: 89),
    QuranSurahInfo(index: 44, name: "الدخان", ayahCount: 59),
    QuranSurahInfo(index: 45, name: "الجاثية", ayahCount: 37),
    QuranSurahInfo(index: 46, name: "الأحقاف", ayahCount: 35),
    QuranSurahInfo(index: 47, name: "محمد", ayahCount: 38),
    QuranSurahInfo(index: 48, name: "الفتح", ayahCount: 29),
    QuranSurahInfo(index: 49, name: "الحجرات", ayahCount: 18),
    QuranSurahInfo(index: 50, name: "ق", ayahCount: 45),
    QuranSurahInfo(index: 51, name: "الذاريات", ayahCount: 60),
    QuranSurahInfo(index: 52, name: "الطور", ayahCount: 49),
    QuranSurahInfo(index: 53, name: "النجم", ayahCount: 62),
    QuranSurahInfo(index: 54, name: "القمر", ayahCount: 55),
    QuranSurahInfo(index: 55, name: "الرحمن", ayahCount: 78),
    QuranSurahInfo(index: 56, name: "الواقعة", ayahCount: 96),
    QuranSurahInfo(index: 57, name: "الحديد", ayahCount: 29),
    QuranSurahInfo(index: 58, name: "المجادلة", ayahCount: 22),
    QuranSurahInfo(index: 59, name: "الحشر", ayahCount: 24),
    QuranSurahInfo(index: 60, name: "الممتحنة", ayahCount: 13),
    QuranSurahInfo(index: 61, name: "الصف", ayahCount: 14),
    QuranSurahInfo(index: 62, name: "الجمعة", ayahCount: 11),
    QuranSurahInfo(index: 63, name: "المنافقون", ayahCount: 11),
    QuranSurahInfo(index: 64, name: "التغابن", ayahCount: 18),
    QuranSurahInfo(index: 65, name: "الطلاق", ayahCount: 12),
    QuranSurahInfo(index: 66, name: "التحريم", ayahCount: 12),
    QuranSurahInfo(index: 67, name: "الملك", ayahCount: 30),
    QuranSurahInfo(index: 68, name: "القلم", ayahCount: 52),
    QuranSurahInfo(index: 69, name: "الحاقة", ayahCount: 52),
    QuranSurahInfo(index: 70, name: "المعارج", ayahCount: 44),
    QuranSurahInfo(index: 71, name: "نوح", ayahCount: 28),
    QuranSurahInfo(index: 72, name: "الجن", ayahCount: 28),
    QuranSurahInfo(index: 73, name: "المزمل", ayahCount: 20),
    QuranSurahInfo(index: 74, name: "المدثر", ayahCount: 56),
    QuranSurahInfo(index: 75, name: "القيامة", ayahCount: 40),
    QuranSurahInfo(index: 76, name: "الإنسان", ayahCount: 31),
    QuranSurahInfo(index: 77, name: "المرسلات", ayahCount: 50),
    QuranSurahInfo(index: 78, name: "النبأ", ayahCount: 40),
    QuranSurahInfo(index: 79, name: "النازعات", ayahCount: 46),
    QuranSurahInfo(index: 80, name: "عبس", ayahCount: 42),
    QuranSurahInfo(index: 81, name: "التكوير", ayahCount: 29),
    QuranSurahInfo(index: 82, name: "الانفطار", ayahCount: 19),
    QuranSurahInfo(index: 83, name: "المطففين", ayahCount: 36),
    QuranSurahInfo(index: 84, name: "الانشقاق", ayahCount: 25),
    QuranSurahInfo(index: 85, name: "البروج", ayahCount: 22),
    QuranSurahInfo(index: 86, name: "الطارق", ayahCount: 17),
    QuranSurahInfo(index: 87, name: "الأعلى", ayahCount: 19),
    QuranSurahInfo(index: 88, name: "الغاشية", ayahCount: 26),
    QuranSurahInfo(index: 89, name: "الفجر", ayahCount: 30),
    QuranSurahInfo(index: 90, name: "البلد", ayahCount: 20),
    QuranSurahInfo(index: 91, name: "الشمس", ayahCount: 15),
    QuranSurahInfo(index: 92, name: "الليل", ayahCount: 21),
    QuranSurahInfo(index: 93, name: "الضحى", ayahCount: 11),
    QuranSurahInfo(index: 94, name: "الشرح", ayahCount: 8),
    QuranSurahInfo(index: 95, name: "التين", ayahCount: 8),
    QuranSurahInfo(index: 96, name: "العلق", ayahCount: 19),
    QuranSurahInfo(index: 97, name: "القدر", ayahCount: 5),
    QuranSurahInfo(index: 98, name: "البينة", ayahCount: 8),
    QuranSurahInfo(index: 99, name: "الزلزلة", ayahCount: 8),
    QuranSurahInfo(index: 100, name: "العاديات", ayahCount: 11),
    QuranSurahInfo(index: 101, name: "القارعة", ayahCount: 11),
    QuranSurahInfo(index: 102, name: "التكاثر", ayahCount: 8),
    QuranSurahInfo(index: 103, name: "العصر", ayahCount: 3),
    QuranSurahInfo(index: 104, name: "الهمزة", ayahCount: 9),
    QuranSurahInfo(index: 105, name: "الفيل", ayahCount: 5),
    QuranSurahInfo(index: 106, name: "قريش", ayahCount: 4),
    QuranSurahInfo(index: 107, name: "الماعون", ayahCount: 7),
    QuranSurahInfo(index: 108, name: "الكوثر", ayahCount: 3),
    QuranSurahInfo(index: 109, name: "الكافرون", ayahCount: 6),
    QuranSurahInfo(index: 110, name: "النصر", ayahCount: 3),
    QuranSurahInfo(index: 111, name: "المسد", ayahCount: 5),
    QuranSurahInfo(index: 112, name: "الإخلاص", ayahCount: 4),
    QuranSurahInfo(index: 113, name: "الفلق", ayahCount: 5),
    QuranSurahInfo(index: 114, name: "الناس", ayahCount: 6)
]

private let quranRubMetadataLookup: [Int: QuranRubMetadata] = [
    1: QuranRubMetadata(startPage: 1, endPage: 5, startSurah: "الفاتحة", endSurah: "البقرة"),
    2: QuranRubMetadata(startPage: 5, endPage: 7, startSurah: "البقرة", endSurah: "البقرة"),
    3: QuranRubMetadata(startPage: 7, endPage: 9, startSurah: "البقرة", endSurah: "البقرة"),
    4: QuranRubMetadata(startPage: 9, endPage: 11, startSurah: "البقرة", endSurah: "البقرة"),
    5: QuranRubMetadata(startPage: 11, endPage: 14, startSurah: "البقرة", endSurah: "البقرة"),
    6: QuranRubMetadata(startPage: 14, endPage: 16, startSurah: "البقرة", endSurah: "البقرة"),
    7: QuranRubMetadata(startPage: 17, endPage: 19, startSurah: "البقرة", endSurah: "البقرة"),
    8: QuranRubMetadata(startPage: 19, endPage: 21, startSurah: "البقرة", endSurah: "البقرة"),
    9: QuranRubMetadata(startPage: 22, endPage: 24, startSurah: "البقرة", endSurah: "البقرة"),
    10: QuranRubMetadata(startPage: 24, endPage: 26, startSurah: "البقرة", endSurah: "البقرة"),
    11: QuranRubMetadata(startPage: 27, endPage: 29, startSurah: "البقرة", endSurah: "البقرة"),
    12: QuranRubMetadata(startPage: 29, endPage: 31, startSurah: "البقرة", endSurah: "البقرة"),
    13: QuranRubMetadata(startPage: 32, endPage: 34, startSurah: "البقرة", endSurah: "البقرة"),
    14: QuranRubMetadata(startPage: 34, endPage: 37, startSurah: "البقرة", endSurah: "البقرة"),
    15: QuranRubMetadata(startPage: 37, endPage: 39, startSurah: "البقرة", endSurah: "البقرة"),
    16: QuranRubMetadata(startPage: 39, endPage: 41, startSurah: "البقرة", endSurah: "البقرة"),
    17: QuranRubMetadata(startPage: 42, endPage: 44, startSurah: "البقرة", endSurah: "البقرة"),
    18: QuranRubMetadata(startPage: 44, endPage: 46, startSurah: "البقرة", endSurah: "البقرة"),
    19: QuranRubMetadata(startPage: 46, endPage: 48, startSurah: "البقرة", endSurah: "البقرة"),
    20: QuranRubMetadata(startPage: 49, endPage: 51, startSurah: "البقرة", endSurah: "آل عمران"),
    21: QuranRubMetadata(startPage: 51, endPage: 54, startSurah: "آل عمران", endSurah: "آل عمران"),
    22: QuranRubMetadata(startPage: 54, endPage: 56, startSurah: "آل عمران", endSurah: "آل عمران"),
    23: QuranRubMetadata(startPage: 56, endPage: 59, startSurah: "آل عمران", endSurah: "آل عمران"),
    24: QuranRubMetadata(startPage: 59, endPage: 62, startSurah: "آل عمران", endSurah: "آل عمران"),
    25: QuranRubMetadata(startPage: 62, endPage: 64, startSurah: "آل عمران", endSurah: "آل عمران"),
    26: QuranRubMetadata(startPage: 64, endPage: 66, startSurah: "آل عمران", endSurah: "آل عمران"),
    27: QuranRubMetadata(startPage: 67, endPage: 69, startSurah: "آل عمران", endSurah: "آل عمران"),
    28: QuranRubMetadata(startPage: 69, endPage: 72, startSurah: "آل عمران", endSurah: "آل عمران"),
    29: QuranRubMetadata(startPage: 72, endPage: 74, startSurah: "آل عمران", endSurah: "آل عمران"),
    30: QuranRubMetadata(startPage: 74, endPage: 76, startSurah: "آل عمران", endSurah: "آل عمران"),
    31: QuranRubMetadata(startPage: 77, endPage: 78, startSurah: "النساء", endSurah: "النساء"),
    32: QuranRubMetadata(startPage: 79, endPage: 81, startSurah: "النساء", endSurah: "النساء"),
    33: QuranRubMetadata(startPage: 82, endPage: 84, startSurah: "النساء", endSurah: "النساء"),
    34: QuranRubMetadata(startPage: 84, endPage: 87, startSurah: "النساء", endSurah: "النساء"),
    35: QuranRubMetadata(startPage: 87, endPage: 89, startSurah: "النساء", endSurah: "النساء"),
    36: QuranRubMetadata(startPage: 89, endPage: 92, startSurah: "النساء", endSurah: "النساء"),
    37: QuranRubMetadata(startPage: 92, endPage: 94, startSurah: "النساء", endSurah: "النساء"),
    38: QuranRubMetadata(startPage: 94, endPage: 96, startSurah: "النساء", endSurah: "النساء"),
    39: QuranRubMetadata(startPage: 97, endPage: 99, startSurah: "النساء", endSurah: "النساء"),
    40: QuranRubMetadata(startPage: 100, endPage: 101, startSurah: "النساء", endSurah: "النساء"),
    41: QuranRubMetadata(startPage: 102, endPage: 103, startSurah: "النساء", endSurah: "النساء"),
    42: QuranRubMetadata(startPage: 104, endPage: 106, startSurah: "النساء", endSurah: "النساء"),
    43: QuranRubMetadata(startPage: 106, endPage: 109, startSurah: "المائدة", endSurah: "المائدة"),
    44: QuranRubMetadata(startPage: 109, endPage: 112, startSurah: "المائدة", endSurah: "المائدة"),
    45: QuranRubMetadata(startPage: 112, endPage: 114, startSurah: "المائدة", endSurah: "المائدة"),
    46: QuranRubMetadata(startPage: 114, endPage: 116, startSurah: "المائدة", endSurah: "المائدة"),
    47: QuranRubMetadata(startPage: 117, endPage: 119, startSurah: "المائدة", endSurah: "المائدة"),
    48: QuranRubMetadata(startPage: 119, endPage: 121, startSurah: "المائدة", endSurah: "المائدة"),
    49: QuranRubMetadata(startPage: 121, endPage: 124, startSurah: "المائدة", endSurah: "المائدة"),
    50: QuranRubMetadata(startPage: 124, endPage: 125, startSurah: "المائدة", endSurah: "المائدة"),
    51: QuranRubMetadata(startPage: 126, endPage: 129, startSurah: "المائدة", endSurah: "الأنعام"),
    52: QuranRubMetadata(startPage: 129, endPage: 131, startSurah: "الأنعام", endSurah: "الأنعام"),
    53: QuranRubMetadata(startPage: 132, endPage: 134, startSurah: "الأنعام", endSurah: "الأنعام"),
    54: QuranRubMetadata(startPage: 134, endPage: 136, startSurah: "الأنعام", endSurah: "الأنعام"),
    55: QuranRubMetadata(startPage: 137, endPage: 139, startSurah: "الأنعام", endSurah: "الأنعام"),
    56: QuranRubMetadata(startPage: 140, endPage: 141, startSurah: "الأنعام", endSurah: "الأنعام"),
    57: QuranRubMetadata(startPage: 142, endPage: 144, startSurah: "الأنعام", endSurah: "الأنعام"),
    58: QuranRubMetadata(startPage: 144, endPage: 146, startSurah: "الأنعام", endSurah: "الأنعام"),
    59: QuranRubMetadata(startPage: 146, endPage: 148, startSurah: "الأنعام", endSurah: "الأنعام"),
    60: QuranRubMetadata(startPage: 148, endPage: 150, startSurah: "الأنعام", endSurah: "الأنعام"),
    61: QuranRubMetadata(startPage: 151, endPage: 153, startSurah: "الأعراف", endSurah: "الأعراف"),
    62: QuranRubMetadata(startPage: 154, endPage: 156, startSurah: "الأعراف", endSurah: "الأعراف"),
    63: QuranRubMetadata(startPage: 156, endPage: 158, startSurah: "الأعراف", endSurah: "الأعراف"),
    64: QuranRubMetadata(startPage: 158, endPage: 161, startSurah: "الأعراف", endSurah: "الأعراف"),
    65: QuranRubMetadata(startPage: 162, endPage: 164, startSurah: "الأعراف", endSurah: "الأعراف"),
    66: QuranRubMetadata(startPage: 164, endPage: 167, startSurah: "الأعراف", endSurah: "الأعراف"),
    67: QuranRubMetadata(startPage: 167, endPage: 169, startSurah: "الأعراف", endSurah: "الأعراف"),
    68: QuranRubMetadata(startPage: 170, endPage: 172, startSurah: "الأعراف", endSurah: "الأعراف"),
    69: QuranRubMetadata(startPage: 173, endPage: 175, startSurah: "الأعراف", endSurah: "الأعراف"),
    70: QuranRubMetadata(startPage: 175, endPage: 176, startSurah: "الأعراف", endSurah: "الأعراف"),
    71: QuranRubMetadata(startPage: 177, endPage: 179, startSurah: "الأنفال", endSurah: "الأنفال"),
    72: QuranRubMetadata(startPage: 179, endPage: 181, startSurah: "الأنفال", endSurah: "الأنفال"),
    73: QuranRubMetadata(startPage: 182, endPage: 184, startSurah: "الأنفال", endSurah: "الأنفال"),
    74: QuranRubMetadata(startPage: 184, endPage: 186, startSurah: "الأنفال", endSurah: "الأنفال"),
    75: QuranRubMetadata(startPage: 187, endPage: 189, startSurah: "التوبة", endSurah: "التوبة"),
    76: QuranRubMetadata(startPage: 189, endPage: 192, startSurah: "التوبة", endSurah: "التوبة"),
    77: QuranRubMetadata(startPage: 192, endPage: 194, startSurah: "التوبة", endSurah: "التوبة"),
    78: QuranRubMetadata(startPage: 194, endPage: 196, startSurah: "التوبة", endSurah: "التوبة"),
    79: QuranRubMetadata(startPage: 196, endPage: 199, startSurah: "التوبة", endSurah: "التوبة"),
    80: QuranRubMetadata(startPage: 199, endPage: 201, startSurah: "التوبة", endSurah: "التوبة"),
    81: QuranRubMetadata(startPage: 201, endPage: 204, startSurah: "التوبة", endSurah: "التوبة"),
    82: QuranRubMetadata(startPage: 204, endPage: 206, startSurah: "التوبة", endSurah: "التوبة"),
    83: QuranRubMetadata(startPage: 206, endPage: 209, startSurah: "التوبة", endSurah: "يونس"),
    84: QuranRubMetadata(startPage: 209, endPage: 211, startSurah: "يونس", endSurah: "يونس"),
    85: QuranRubMetadata(startPage: 212, endPage: 214, startSurah: "يونس", endSurah: "يونس"),
    86: QuranRubMetadata(startPage: 214, endPage: 216, startSurah: "يونس", endSurah: "يونس"),
    87: QuranRubMetadata(startPage: 217, endPage: 219, startSurah: "يونس", endSurah: "يونس"),
    88: QuranRubMetadata(startPage: 219, endPage: 221, startSurah: "يونس", endSurah: "هود"),
    89: QuranRubMetadata(startPage: 222, endPage: 224, startSurah: "هود", endSurah: "هود"),
    90: QuranRubMetadata(startPage: 224, endPage: 226, startSurah: "هود", endSurah: "هود"),
    91: QuranRubMetadata(startPage: 226, endPage: 228, startSurah: "هود", endSurah: "هود"),
    92: QuranRubMetadata(startPage: 228, endPage: 231, startSurah: "هود", endSurah: "هود"),
    93: QuranRubMetadata(startPage: 231, endPage: 233, startSurah: "هود", endSurah: "هود"),
    94: QuranRubMetadata(startPage: 233, endPage: 236, startSurah: "هود", endSurah: "يوسف"),
    95: QuranRubMetadata(startPage: 236, endPage: 238, startSurah: "يوسف", endSurah: "يوسف"),
    96: QuranRubMetadata(startPage: 238, endPage: 241, startSurah: "يوسف", endSurah: "يوسف"),
    97: QuranRubMetadata(startPage: 242, endPage: 244, startSurah: "يوسف", endSurah: "يوسف"),
    98: QuranRubMetadata(startPage: 244, endPage: 247, startSurah: "يوسف", endSurah: "يوسف"),
    99: QuranRubMetadata(startPage: 247, endPage: 249, startSurah: "يوسف", endSurah: "الرعد"),
    100: QuranRubMetadata(startPage: 249, endPage: 251, startSurah: "الرعد", endSurah: "الرعد"),
    101: QuranRubMetadata(startPage: 252, endPage: 253, startSurah: "الرعد", endSurah: "الرعد"),
    102: QuranRubMetadata(startPage: 254, endPage: 256, startSurah: "الرعد", endSurah: "ابراهيم"),
    103: QuranRubMetadata(startPage: 256, endPage: 259, startSurah: "ابراهيم", endSurah: "ابراهيم"),
    104: QuranRubMetadata(startPage: 259, endPage: 261, startSurah: "ابراهيم", endSurah: "ابراهيم"),
    105: QuranRubMetadata(startPage: 262, endPage: 264, startSurah: "الحجر", endSurah: "الحجر"),
    106: QuranRubMetadata(startPage: 264, endPage: 267, startSurah: "الحجر", endSurah: "الحجر"),
    107: QuranRubMetadata(startPage: 267, endPage: 270, startSurah: "النحل", endSurah: "النحل"),
    108: QuranRubMetadata(startPage: 270, endPage: 272, startSurah: "النحل", endSurah: "النحل"),
    109: QuranRubMetadata(startPage: 272, endPage: 275, startSurah: "النحل", endSurah: "النحل"),
    110: QuranRubMetadata(startPage: 275, endPage: 277, startSurah: "النحل", endSurah: "النحل"),
    111: QuranRubMetadata(startPage: 277, endPage: 279, startSurah: "النحل", endSurah: "النحل"),
    112: QuranRubMetadata(startPage: 280, endPage: 281, startSurah: "النحل", endSurah: "النحل"),
    113: QuranRubMetadata(startPage: 282, endPage: 284, startSurah: "الإسراء", endSurah: "الإسراء"),
    114: QuranRubMetadata(startPage: 284, endPage: 286, startSurah: "الإسراء", endSurah: "الإسراء"),
    115: QuranRubMetadata(startPage: 287, endPage: 289, startSurah: "الإسراء", endSurah: "الإسراء"),
    116: QuranRubMetadata(startPage: 289, endPage: 292, startSurah: "الإسراء", endSurah: "الإسراء"),
    117: QuranRubMetadata(startPage: 292, endPage: 295, startSurah: "الإسراء", endSurah: "الكهف"),
    118: QuranRubMetadata(startPage: 295, endPage: 297, startSurah: "الكهف", endSurah: "الكهف"),
    119: QuranRubMetadata(startPage: 297, endPage: 299, startSurah: "الكهف", endSurah: "الكهف"),
    120: QuranRubMetadata(startPage: 299, endPage: 301, startSurah: "الكهف", endSurah: "الكهف"),
    121: QuranRubMetadata(startPage: 302, endPage: 304, startSurah: "الكهف", endSurah: "الكهف"),
    122: QuranRubMetadata(startPage: 304, endPage: 306, startSurah: "الكهف", endSurah: "مريم"),
    123: QuranRubMetadata(startPage: 306, endPage: 309, startSurah: "مريم", endSurah: "مريم"),
    124: QuranRubMetadata(startPage: 309, endPage: 312, startSurah: "مريم", endSurah: "مريم"),
    125: QuranRubMetadata(startPage: 312, endPage: 315, startSurah: "طه", endSurah: "طه"),
    126: QuranRubMetadata(startPage: 315, endPage: 317, startSurah: "طه", endSurah: "طه"),
    127: QuranRubMetadata(startPage: 317, endPage: 319, startSurah: "طه", endSurah: "طه"),
    128: QuranRubMetadata(startPage: 319, endPage: 321, startSurah: "طه", endSurah: "طه"),
    129: QuranRubMetadata(startPage: 322, endPage: 324, startSurah: "الأنبياء", endSurah: "الأنبياء"),
    130: QuranRubMetadata(startPage: 324, endPage: 326, startSurah: "الأنبياء", endSurah: "الأنبياء"),
    131: QuranRubMetadata(startPage: 326, endPage: 329, startSurah: "الأنبياء", endSurah: "الأنبياء"),
    132: QuranRubMetadata(startPage: 329, endPage: 331, startSurah: "الأنبياء", endSurah: "الأنبياء"),
    133: QuranRubMetadata(startPage: 332, endPage: 334, startSurah: "الحج", endSurah: "الحج"),
    134: QuranRubMetadata(startPage: 334, endPage: 336, startSurah: "الحج", endSurah: "الحج"),
    135: QuranRubMetadata(startPage: 336, endPage: 339, startSurah: "الحج", endSurah: "الحج"),
    136: QuranRubMetadata(startPage: 339, endPage: 341, startSurah: "الحج", endSurah: "الحج"),
    137: QuranRubMetadata(startPage: 342, endPage: 344, startSurah: "المؤمنون", endSurah: "المؤمنون"),
    138: QuranRubMetadata(startPage: 344, endPage: 346, startSurah: "المؤمنون", endSurah: "المؤمنون"),
    139: QuranRubMetadata(startPage: 347, endPage: 349, startSurah: "المؤمنون", endSurah: "المؤمنون"),
    140: QuranRubMetadata(startPage: 350, endPage: 351, startSurah: "النور", endSurah: "النور"),
    141: QuranRubMetadata(startPage: 352, endPage: 354, startSurah: "النور", endSurah: "النور"),
    142: QuranRubMetadata(startPage: 354, endPage: 356, startSurah: "النور", endSurah: "النور"),
    143: QuranRubMetadata(startPage: 356, endPage: 359, startSurah: "النور", endSurah: "النور"),
    144: QuranRubMetadata(startPage: 359, endPage: 361, startSurah: "الفرقان", endSurah: "الفرقان"),
    145: QuranRubMetadata(startPage: 362, endPage: 364, startSurah: "الفرقان", endSurah: "الفرقان"),
    146: QuranRubMetadata(startPage: 364, endPage: 366, startSurah: "الفرقان", endSurah: "الفرقان"),
    147: QuranRubMetadata(startPage: 367, endPage: 369, startSurah: "الشعراء", endSurah: "الشعراء"),
    148: QuranRubMetadata(startPage: 369, endPage: 371, startSurah: "الشعراء", endSurah: "الشعراء"),
    149: QuranRubMetadata(startPage: 371, endPage: 374, startSurah: "الشعراء", endSurah: "الشعراء"),
    150: QuranRubMetadata(startPage: 374, endPage: 376, startSurah: "الشعراء", endSurah: "الشعراء"),
    151: QuranRubMetadata(startPage: 377, endPage: 379, startSurah: "النمل", endSurah: "النمل"),
    152: QuranRubMetadata(startPage: 379, endPage: 381, startSurah: "النمل", endSurah: "النمل"),
    153: QuranRubMetadata(startPage: 382, endPage: 384, startSurah: "النمل", endSurah: "النمل"),
    154: QuranRubMetadata(startPage: 384, endPage: 386, startSurah: "النمل", endSurah: "القصص"),
    155: QuranRubMetadata(startPage: 386, endPage: 388, startSurah: "القصص", endSurah: "القصص"),
    156: QuranRubMetadata(startPage: 389, endPage: 391, startSurah: "القصص", endSurah: "القصص"),
    157: QuranRubMetadata(startPage: 392, endPage: 394, startSurah: "القصص", endSurah: "القصص"),
    158: QuranRubMetadata(startPage: 394, endPage: 396, startSurah: "القصص", endSurah: "القصص"),
    159: QuranRubMetadata(startPage: 396, endPage: 399, startSurah: "العنكبوت", endSurah: "العنكبوت"),
    160: QuranRubMetadata(startPage: 399, endPage: 401, startSurah: "العنكبوت", endSurah: "العنكبوت"),
    161: QuranRubMetadata(startPage: 402, endPage: 404, startSurah: "العنكبوت", endSurah: "العنكبوت"),
    162: QuranRubMetadata(startPage: 404, endPage: 407, startSurah: "الروم", endSurah: "الروم"),
    163: QuranRubMetadata(startPage: 407, endPage: 410, startSurah: "الروم", endSurah: "الروم"),
    164: QuranRubMetadata(startPage: 410, endPage: 413, startSurah: "الروم", endSurah: "لقمان"),
    165: QuranRubMetadata(startPage: 413, endPage: 415, startSurah: "لقمان", endSurah: "السجدة"),
    166: QuranRubMetadata(startPage: 415, endPage: 417, startSurah: "السجدة", endSurah: "السجدة"),
    167: QuranRubMetadata(startPage: 418, endPage: 420, startSurah: "الأحزاب", endSurah: "الأحزاب"),
    168: QuranRubMetadata(startPage: 420, endPage: 421, startSurah: "الأحزاب", endSurah: "الأحزاب"),
    169: QuranRubMetadata(startPage: 422, endPage: 424, startSurah: "الأحزاب", endSurah: "الأحزاب"),
    170: QuranRubMetadata(startPage: 425, endPage: 426, startSurah: "الأحزاب", endSurah: "الأحزاب"),
    171: QuranRubMetadata(startPage: 426, endPage: 429, startSurah: "الأحزاب", endSurah: "سبإ"),
    172: QuranRubMetadata(startPage: 429, endPage: 431, startSurah: "سبإ", endSurah: "سبإ"),
    173: QuranRubMetadata(startPage: 431, endPage: 433, startSurah: "سبإ", endSurah: "سبإ"),
    174: QuranRubMetadata(startPage: 433, endPage: 436, startSurah: "سبإ", endSurah: "فاطر"),
    175: QuranRubMetadata(startPage: 436, endPage: 439, startSurah: "فاطر", endSurah: "فاطر"),
    176: QuranRubMetadata(startPage: 439, endPage: 441, startSurah: "فاطر", endSurah: "يس"),
    177: QuranRubMetadata(startPage: 442, endPage: 444, startSurah: "يس", endSurah: "يس"),
    178: QuranRubMetadata(startPage: 444, endPage: 446, startSurah: "يس", endSurah: "الصافات"),
    179: QuranRubMetadata(startPage: 446, endPage: 449, startSurah: "الصافات", endSurah: "الصافات"),
    180: QuranRubMetadata(startPage: 449, endPage: 451, startSurah: "الصافات", endSurah: "الصافات"),
    181: QuranRubMetadata(startPage: 451, endPage: 454, startSurah: "الصافات", endSurah: "ص"),
    182: QuranRubMetadata(startPage: 454, endPage: 456, startSurah: "ص", endSurah: "ص"),
    183: QuranRubMetadata(startPage: 456, endPage: 459, startSurah: "ص", endSurah: "الزمر"),
    184: QuranRubMetadata(startPage: 459, endPage: 461, startSurah: "الزمر", endSurah: "الزمر"),
    185: QuranRubMetadata(startPage: 462, endPage: 464, startSurah: "الزمر", endSurah: "الزمر"),
    186: QuranRubMetadata(startPage: 464, endPage: 467, startSurah: "الزمر", endSurah: "الزمر"),
    187: QuranRubMetadata(startPage: 467, endPage: 469, startSurah: "غافر", endSurah: "غافر"),
    188: QuranRubMetadata(startPage: 469, endPage: 471, startSurah: "غافر", endSurah: "غافر"),
    189: QuranRubMetadata(startPage: 472, endPage: 474, startSurah: "غافر", endSurah: "غافر"),
    190: QuranRubMetadata(startPage: 474, endPage: 477, startSurah: "غافر", endSurah: "فصلت"),
    191: QuranRubMetadata(startPage: 477, endPage: 479, startSurah: "فصلت", endSurah: "فصلت"),
    192: QuranRubMetadata(startPage: 479, endPage: 481, startSurah: "فصلت", endSurah: "فصلت"),
    193: QuranRubMetadata(startPage: 482, endPage: 484, startSurah: "فصلت", endSurah: "الشورى"),
    194: QuranRubMetadata(startPage: 484, endPage: 486, startSurah: "الشورى", endSurah: "الشورى"),
    195: QuranRubMetadata(startPage: 486, endPage: 488, startSurah: "الشورى", endSurah: "الشورى"),
    196: QuranRubMetadata(startPage: 488, endPage: 491, startSurah: "الشورى", endSurah: "الزخرف"),
    197: QuranRubMetadata(startPage: 491, endPage: 493, startSurah: "الزخرف", endSurah: "الزخرف"),
    198: QuranRubMetadata(startPage: 493, endPage: 496, startSurah: "الزخرف", endSurah: "الدخان"),
    199: QuranRubMetadata(startPage: 496, endPage: 499, startSurah: "الدخان", endSurah: "الجاثية"),
    200: QuranRubMetadata(startPage: 499, endPage: 502, startSurah: "الجاثية", endSurah: "الجاثية"),
    201: QuranRubMetadata(startPage: 502, endPage: 504, startSurah: "الأحقاف", endSurah: "الأحقاف"),
    202: QuranRubMetadata(startPage: 505, endPage: 507, startSurah: "الأحقاف", endSurah: "محمد"),
    203: QuranRubMetadata(startPage: 507, endPage: 510, startSurah: "محمد", endSurah: "محمد"),
    204: QuranRubMetadata(startPage: 510, endPage: 513, startSurah: "محمد", endSurah: "الفتح"),
    205: QuranRubMetadata(startPage: 513, endPage: 515, startSurah: "الفتح", endSurah: "الفتح"),
    206: QuranRubMetadata(startPage: 515, endPage: 517, startSurah: "الحجرات", endSurah: "الحجرات"),
    207: QuranRubMetadata(startPage: 517, endPage: 519, startSurah: "الحجرات", endSurah: "ق"),
    208: QuranRubMetadata(startPage: 519, endPage: 521, startSurah: "ق", endSurah: "الذاريات"),
    209: QuranRubMetadata(startPage: 522, endPage: 524, startSurah: "الذاريات", endSurah: "الطور"),
    210: QuranRubMetadata(startPage: 524, endPage: 526, startSurah: "الطور", endSurah: "النجم"),
    211: QuranRubMetadata(startPage: 526, endPage: 529, startSurah: "النجم", endSurah: "القمر"),
    212: QuranRubMetadata(startPage: 529, endPage: 531, startSurah: "القمر", endSurah: "القمر"),
    213: QuranRubMetadata(startPage: 531, endPage: 534, startSurah: "الرحمن", endSurah: "الرحمن"),
    214: QuranRubMetadata(startPage: 534, endPage: 536, startSurah: "الواقعة", endSurah: "الواقعة"),
    215: QuranRubMetadata(startPage: 536, endPage: 539, startSurah: "الواقعة", endSurah: "الحديد"),
    216: QuranRubMetadata(startPage: 539, endPage: 541, startSurah: "الحديد", endSurah: "الحديد"),
    217: QuranRubMetadata(startPage: 542, endPage: 544, startSurah: "المجادلة", endSurah: "المجادلة"),
    218: QuranRubMetadata(startPage: 544, endPage: 547, startSurah: "المجادلة", endSurah: "الحشر"),
    219: QuranRubMetadata(startPage: 547, endPage: 550, startSurah: "الحشر", endSurah: "الممتحنة"),
    220: QuranRubMetadata(startPage: 550, endPage: 552, startSurah: "الممتحنة", endSurah: "الصف"),
    221: QuranRubMetadata(startPage: 553, endPage: 554, startSurah: "الجمعة", endSurah: "المنافقون"),
    222: QuranRubMetadata(startPage: 554, endPage: 557, startSurah: "المنافقون", endSurah: "التغابن"),
    223: QuranRubMetadata(startPage: 558, endPage: 559, startSurah: "الطلاق", endSurah: "الطلاق"),
    224: QuranRubMetadata(startPage: 560, endPage: 561, startSurah: "التحريم", endSurah: "التحريم"),
    225: QuranRubMetadata(startPage: 562, endPage: 564, startSurah: "الملك", endSurah: "الملك"),
    226: QuranRubMetadata(startPage: 564, endPage: 566, startSurah: "القلم", endSurah: "القلم"),
    227: QuranRubMetadata(startPage: 566, endPage: 569, startSurah: "الحاقة", endSurah: "المعارج"),
    228: QuranRubMetadata(startPage: 569, endPage: 571, startSurah: "المعارج", endSurah: "نوح"),
    229: QuranRubMetadata(startPage: 572, endPage: 574, startSurah: "الجن", endSurah: "المزمل"),
    230: QuranRubMetadata(startPage: 575, endPage: 577, startSurah: "المزمل", endSurah: "المدثر"),
    231: QuranRubMetadata(startPage: 577, endPage: 579, startSurah: "القيامة", endSurah: "الانسان"),
    232: QuranRubMetadata(startPage: 579, endPage: 581, startSurah: "الانسان", endSurah: "المرسلات"),
    233: QuranRubMetadata(startPage: 582, endPage: 584, startSurah: "النبإ", endSurah: "النازعات"),
    234: QuranRubMetadata(startPage: 585, endPage: 586, startSurah: "عبس", endSurah: "التكوير"),
    235: QuranRubMetadata(startPage: 587, endPage: 589, startSurah: "الإنفطار", endSurah: "المطففين"),
    236: QuranRubMetadata(startPage: 589, endPage: 591, startSurah: "الإنشقاق", endSurah: "الطارق"),
    237: QuranRubMetadata(startPage: 591, endPage: 594, startSurah: "الأعلى", endSurah: "الفجر"),
    238: QuranRubMetadata(startPage: 594, endPage: 596, startSurah: "البلد", endSurah: "الضحى"),
    239: QuranRubMetadata(startPage: 596, endPage: 599, startSurah: "الشرح", endSurah: "العاديات"),
    240: QuranRubMetadata(startPage: 599, endPage: 604, startSurah: "العاديات", endSurah: "الناس"),
]