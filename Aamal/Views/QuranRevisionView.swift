import SwiftUI

struct QuranRevisionView: View {
    @ObservedObject var store: TaskStore
    @State private var juzCount: Int
    @State private var additionalHizb: Int
    @State private var additionalRub: Int
    @State private var dailyGoalRubs: Int
    @State private var recentWindowRubs: Int
    @State private var newMemorizationTargetRubs: Int
    @State private var fajrCapacity: Int
    @State private var dhuhrCapacity: Int
    @State private var asrCapacity: Int
    @State private var maghribCapacity: Int
    @State private var ishaCapacity: Int
    @State private var qiyamEnabled: Bool
    @State private var qiyamStartSurahIndex: Int
    @State private var qiyamStartAyah: Int
    @State private var qiyamStopSurahIndex: Int
    @State private var qiyamStopAyah: Int
    @State private var feedbackMessage: String = ""
    @State private var showSettingsSheet = false

    init(store: TaskStore) {
        self.store = store

        let totalRubs = store.quranRevisionPlan.totalMemorizedRubs
        let qiyamStartReference = store.todaysQiyamSession?.startAyah
            ?? store.qiyamLoggingStartReference()
            ?? QuranAyahCatalog.reference(surahIndex: 1, ayah: 1)
        let qiyamStopReference = store.todaysQiyamSession?.endAyah ?? qiyamStartReference
        let juz = totalRubs / 8
        let remainder = totalRubs % 8

        _juzCount = State(initialValue: juz)
        _additionalHizb = State(initialValue: remainder / 4)
        _additionalRub = State(initialValue: remainder % 4)
        _dailyGoalRubs = State(initialValue: store.quranRevisionPlan.dailyGoalRubs)
        _recentWindowRubs = State(initialValue: store.quranRevisionPlan.recentWindowRubs)
        _newMemorizationTargetRubs = State(initialValue: store.quranRevisionPlan.newMemorizationTargetRubs)
        _fajrCapacity = State(initialValue: store.quranRevisionPlan.capacity(for: .fajr))
        _dhuhrCapacity = State(initialValue: store.quranRevisionPlan.capacity(for: .dhuhr))
        _asrCapacity = State(initialValue: store.quranRevisionPlan.capacity(for: .asr))
        _maghribCapacity = State(initialValue: store.quranRevisionPlan.capacity(for: .maghrib))
        _ishaCapacity = State(initialValue: store.quranRevisionPlan.capacity(for: .isha))
        _qiyamEnabled = State(initialValue: store.quranRevisionPlan.qiyamEnabled)
        _qiyamStartSurahIndex = State(initialValue: qiyamStartReference?.surahIndex ?? 1)
        _qiyamStartAyah = State(initialValue: qiyamStartReference?.ayah ?? 1)
        _qiyamStopSurahIndex = State(initialValue: qiyamStopReference?.surahIndex ?? 1)
        _qiyamStopAyah = State(initialValue: qiyamStopReference?.ayah ?? 1)
    }

    private var totalDraftRubs: Int {
        min(240, (juzCount * 8) + (additionalHizb * 4) + additionalRub)
    }

    private var todaysPlan: QuranAdaptiveDailyPlan {
        store.todaysAdaptiveQuranPlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AamalTheme.screenSpacing) {
                    QuranAdaptiveHeroCard(
                        store: store,
                        plan: todaysPlan,
                        openSettingsAction: { showSettingsSheet = true }
                    )
                    .aamalEntrance(0)

                    if !feedbackMessage.isEmpty {
                        AamalSectionHeader(
                            title: "تم تحديث الخطة",
                            subtitle: feedbackMessage,
                            tint: AamalTheme.emerald,
                            systemImage: "checkmark.circle.fill"
                        )
                            .aamalCard()
                            .transition(AamalTransition.banner)
                            .aamalEntrance(1)
                    }

                    QuranStrengthDistributionCard(store: store)
                    .aamalEntrance(2)

                    QuranQiyamCard(
                        insight: todaysPlan.qiyamInsight,
                        isEnabled: qiyamEnabled,
                        startLocked: qiyamStartIsLocked,
                        startSummary: qiyamStartReferenceDraft?.title,
                        savedRangeSummary: todaysPlan.qiyamInsight.rangeSummary,
                        startSurahIndex: $qiyamStartSurahIndex,
                        startAyah: $qiyamStartAyah,
                        stopSurahIndex: $qiyamStopSurahIndex,
                        stopAyah: $qiyamStopAyah,
                        computedAyahCount: draftQiyamAyahCount,
                        validationMessage: qiyamValidationMessage,
                        saveAction: saveQiyam,
                        clearAction: clearQiyam,
                        openSettingsAction: { showSettingsSheet = true }
                    )
                    .aamalEntrance(3)

                    if let newItem = todaysPlan.newMemorization {
                        QuranNewMemorizationCard(item: newItem)
                            .aamalEntrance(4)
                    }

                    QuranRequiredRevisionCard(plan: todaysPlan)
                        .aamalEntrance(5)

                    QuranWeakSpotsDashboardCard(
                        plan: todaysPlan,
                        weakRubs: store.quranMarkedWeakRubs,
                        clearWeakAction: clearWeakRub
                    )
                    .aamalEntrance(6)

                    if !todaysPlan.safeguards.isEmpty {
                        QuranPlanSafeguardsCard(plan: todaysPlan)
                            .aamalEntrance(7)
                    }

                    QuranPrayerDistributionCard(
                        store: store,
                        plan: todaysPlan,
                        toggleWeakAction: toggleWeakRub,
                        prayerLogAction: logPrayerRevision,
                        completionAction: markTodayCompleted
                    )
                    .aamalEntrance(8)
                }
                .padding(.horizontal, AamalTheme.sectionSpacing)
                .padding(.bottom, AamalTheme.screenBottomInset)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("إعدادات خطة الحفظ")
                }
            }
            .navigationTitle("خطة الحفظ")
            .navigationBarTitleDisplayMode(.inline)
            .aamalScreen()
        }
        .onAppear(perform: syncDraftFromStore)
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        QuranAdaptiveSettingsCard(
                            juzCount: $juzCount,
                            additionalHizb: $additionalHizb,
                            additionalRub: $additionalRub,
                            dailyGoalRubs: $dailyGoalRubs,
                            recentWindowRubs: $recentWindowRubs,
                            newMemorizationTargetRubs: $newMemorizationTargetRubs,
                            qiyamEnabled: $qiyamEnabled,
                            fajrCapacity: $fajrCapacity,
                            dhuhrCapacity: $dhuhrCapacity,
                            asrCapacity: $asrCapacity,
                            maghribCapacity: $maghribCapacity,
                            ishaCapacity: $ishaCapacity,
                            totalDraftRubs: totalDraftRubs,
                            saveAction: savePlan
                        )
                    }
                    .padding()
                }
                .navigationTitle("إعدادات الخطة")
                .navigationBarTitleDisplayMode(.inline)
                .aamalScreen()
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("إغلاق") {
                            syncDraftFromStore()
                            showSettingsSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func syncDraftFromStore() {
        let totalRubs = store.quranRevisionPlan.totalMemorizedRubs
        juzCount = totalRubs / 8
        let remainder = totalRubs % 8
        additionalHizb = remainder / 4
        additionalRub = remainder % 4
        dailyGoalRubs = store.quranRevisionPlan.dailyGoalRubs
        recentWindowRubs = store.quranRevisionPlan.recentWindowRubs
        newMemorizationTargetRubs = store.quranRevisionPlan.newMemorizationTargetRubs
        fajrCapacity = store.quranRevisionPlan.capacity(for: .fajr)
        dhuhrCapacity = store.quranRevisionPlan.capacity(for: .dhuhr)
        asrCapacity = store.quranRevisionPlan.capacity(for: .asr)
        maghribCapacity = store.quranRevisionPlan.capacity(for: .maghrib)
        ishaCapacity = store.quranRevisionPlan.capacity(for: .isha)
        qiyamEnabled = store.quranRevisionPlan.qiyamEnabled
        let qiyamStartReference = store.todaysQiyamSession?.startAyah
            ?? store.qiyamLoggingStartReference()
            ?? QuranAyahCatalog.reference(surahIndex: 1, ayah: 1)
        let qiyamStopReference = store.todaysQiyamSession?.endAyah ?? qiyamStartReference
        qiyamStartSurahIndex = qiyamStartReference?.surahIndex ?? 1
        qiyamStartAyah = qiyamStartReference?.ayah ?? 1
        qiyamStopSurahIndex = qiyamStopReference?.surahIndex ?? qiyamStartSurahIndex
        qiyamStopAyah = qiyamStopReference?.ayah ?? qiyamStartAyah
    }

    private func savePlan() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            store.configureQuranRevisionPlan(
                juzCount: juzCount,
                additionalHizb: additionalHizb,
                additionalRub: additionalRub,
                dailyGoalRubs: dailyGoalRubs,
                recentWindowRubs: recentWindowRubs,
                newMemorizationTargetRubs: newMemorizationTargetRubs,
                qiyamEnabled: qiyamEnabled,
                prayerCapacities: [
                    .fajr: fajrCapacity,
                    .dhuhr: dhuhrCapacity,
                    .asr: asrCapacity,
                    .maghrib: maghribCapacity,
                    .isha: ishaCapacity
                ]
            )

            feedbackMessage = totalDraftRubs == 0
                ? "تم تصفير الخطة حتى تحدد مقدار المحفوظ."
                : "تم تحديث الخطة اليومية والتوزيع على الصلوات."
        }

        syncDraftFromStore()
        showSettingsSheet = false
    }

    private func saveQiyam() {
        guard let startAyah = qiyamStartReferenceDraft,
              let stopAyah = qiyamStopReferenceDraft else {
            feedbackMessage = "حدد نقطة البداية وآية التوقف أولًا."
            return
        }

        guard let ayatCount = draftQiyamAyahCount else {
            feedbackMessage = "اختر آية توقف بعد نقطة البداية ليحسب التطبيق مقدار ما قرأت."
            return
        }

        let didSave = store.logQiyamSession(from: startAyah, to: stopAyah)
        if didSave {
            feedbackMessage = "تم حفظ موضع التوقف، واحتسب التطبيق \(ayatCount) آية تلقائيًا."
            syncDraftFromStore()
        } else {
            feedbackMessage = "تعذر حفظ موضع التوقف. تأكد أن الموضع الجديد بعد البداية وأن المدى ليس مبالغًا فيه."
        }
    }

    @discardableResult
    private func clearQiyam() -> Bool {
        let didClear = store.clearQiyamSession()
        if didClear {
            syncDraftFromStore()
        }
        return didClear
    }

    private func markTodayCompleted() {
        let didMark = store.markQuranRevisionCompleted()
        feedbackMessage = didMark
            ? "أُنجزت خطة اليوم وتم احتساب نقاط المراجعة."
            : "خطة اليوم مسجلة مسبقًا أو أن الخطة غير مهيأة بعد."
    }

    private func toggleWeakRub(_ rub: QuranRubReference) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            if store.isQuranRubMarkedWeak(rub) {
                feedbackMessage = store.clearQuranRubWeak(rub)
                    ? "أزيل \(rub.shortTitle) من قائمة الضعيف وسيخرج من الاسترجاع اليدوي."
                    : "لم يتغير وسم \(rub.shortTitle)."
            } else {
                feedbackMessage = store.markQuranRubWeak(rub)
                    ? "تم وسم \(rub.shortTitle) كموضع ضعيف وسيدخل مباشرة في مسار الاسترجاع."
                    : "تعذر وسم هذا الموضع كضعيف."
            }
        }
    }

    private func clearWeakRub(_ rub: QuranRubReference) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            feedbackMessage = store.clearQuranRubWeak(rub)
                ? "أزيل \(rub.shortTitle) من قائمة الضعيف."
                : "هذا الموضع غير موجود أصلًا في قائمة الضعيف."
        }
    }

    private func logPrayerRevision(_ prayer: PrayerCompensationType) {
        let didLog = store.markQuranPrayerCompleted(prayer)

        if didLog {
            feedbackMessage = store.isQuranRevisionCompleted()
                ? "تم تسجيل \(prayer.arabicName)، واكتملت خطة اليوم تلقائيًا."
                : "تم تسجيل مراجعة \(prayer.arabicName) بنجاح."
        } else if store.isQuranPrayerCompleted(prayer) {
            feedbackMessage = "\(prayer.arabicName) مسجلة بالفعل اليوم."
        } else {
            feedbackMessage = "لا يوجد مقطع فعلي مخصص لـ \(prayer.arabicName) اليوم حتى يتم تسجيله."
        }
    }

    private var qiyamStartIsLocked: Bool {
        store.qiyamLoggingStartReference() != nil || store.todaysQiyamSession?.startAyah != nil
    }

    private var qiyamStartReferenceDraft: QuranAyahReference? {
        QuranAyahCatalog.reference(surahIndex: qiyamStartSurahIndex, ayah: qiyamStartAyah)
    }

    private var qiyamStopReferenceDraft: QuranAyahReference? {
        QuranAyahCatalog.reference(surahIndex: qiyamStopSurahIndex, ayah: qiyamStopAyah)
    }

    private var draftQiyamAyahCount: Int? {
        guard let startAyah = qiyamStartReferenceDraft,
              let stopAyah = qiyamStopReferenceDraft else {
            return nil
        }

        return QuranAyahCatalog.ayahCount(from: startAyah, to: stopAyah)
    }

    private var qiyamValidationMessage: String? {
        guard qiyamEnabled else { return nil }
        guard draftQiyamAyahCount == nil else { return nil }
        return "يجب أن تكون آية التوقف بعد نقطة البداية حتى يحسب التطبيق مقدار القراءة."
    }
}

private struct QuranAdaptiveHeroCard: View {
    @ObservedObject var store: TaskStore
    let plan: QuranAdaptiveDailyPlan
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("لوحة اليوم")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(plan.statusTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("الهدف: \(plan.goalTitle)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(plan.guidance)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()

                VStack(alignment: .trailing, spacing: 10) {
                    QuranStatusBadge(
                        title: plan.mode.shortTitle,
                        systemImage: plan.mode.systemImage,
                        tint: quranModeTint(for: plan.mode)
                    )

                    Button(action: openSettingsAction) {
                        Label("تعديل", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))
                }
            }

            QuranModeBanner(
                title: store.quranRevisionRankTitle,
                subtitle: plan.newMemorizationAllowed ? "الحفظ الجديد مفتوح اليوم" : "التوسعة متوقفة اليوم لصالح الحماية والاستعادة",
                tint: quranModeTint(for: plan.mode)
            )

            ProgressView(value: store.quranRevisionCompletionRate)
                .tint(AamalTheme.gold)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                QuranMetricPill(
                    title: "المحفوظ",
                    value: quranDescribe(totalRubs: store.quranRevisionPlan.totalMemorizedRubs),
                    accent: AamalTheme.emerald
                )
                QuranMetricPill(
                    title: "سلسلة المراجعة",
                    value: "\(store.quranRevisionPlan.streak) أيام",
                    accent: AamalTheme.gold
                )
                QuranMetricPill(
                    title: "حد الأمان",
                    value: "\(store.quranRevisionPlan.dailyGoalRubs) ربع",
                    accent: quranModeTint(for: plan.mode)
                )
                QuranMetricPill(
                    title: "سعة اليوم",
                    value: "\(store.quranRevisionPlan.totalPrayerCapacityAyahs) آية",
                    accent: AamalTheme.ink.opacity(0.85)
                )
            }
        }
        .padding(AamalTheme.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AamalTheme.solidCardCornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            AamalTheme.surfaceRaised,
                            quranModeTint(for: plan.mode).opacity(0.10),
                            AamalTheme.mint.opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AamalTheme.solidCardCornerRadius)
                        .stroke(quranModeTint(for: plan.mode).opacity(0.16), lineWidth: 1)
                )
                .shadow(color: AamalTheme.shadow, radius: 14, x: 0, y: 8)
        )
    }
}

private struct QuranNewMemorizationCard: View {
    let item: QuranPlanSummaryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(item.kind.title, systemImage: item.kind.systemImage)
                    .font(.headline)
                Spacer()
                Text(item.quantityText)
                    .font(.subheadline)
                    .foregroundColor(AamalTheme.emerald)
            }

            Text(item.rangeText)
                .font(.subheadline)

            Text(quranPageSummary(for: item.rubs))
                .font(.caption)
                .foregroundColor(.secondary)

            Text("يُعرض الجديد فقط عندما يكون حمل المراجعة اليومي آمنًا ومناسبًا لسعتك.")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .aamalCardSolid()
    }
}

private struct QuranRequiredRevisionCard: View {
    let plan: QuranAdaptiveDailyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuranSectionHeader(
                title: "المراجعة المطلوبة",
                subtitle: subtitle,
                tint: quranModeTint(for: plan.mode),
                systemImage: "books.vertical"
            )

            if plan.requiredRevision.isEmpty {
                Text("اضبط المحفوظ وسعة الصلوات ليظهر الحد الأدنى للمراجعة تلقائيًا.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(plan.requiredRevision) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.kind.systemImage)
                            .foregroundColor(quranTint(for: item.kind))
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.kind.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text(item.rangeText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text(item.quantityText)
                                .font(.subheadline)
                            Text("حوالي \(item.estimatedAyahs) آية")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(quranTint(for: item.kind).opacity(0.08))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(quranTint(for: item.kind))
                            .frame(width: 4)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .aamalCard()
    }

    private var subtitle: String {
        switch plan.mode {
        case .normal:
            return "هذا هو الحد الأدنى غير القابل للتفاوض قبل أي زيادة جديدة."
        case .reducedSafety:
            return "هذه نسخة الوقاية الدنيا لليوم المحدود، هدفها إبقاء الاستدعاء حيًا بلا إرهاق."
        case .recoveryReentry:
            return "هذه خطة إعادة الدخول بعد الانقطاع، قصيرة وواضحة لتستعيد الثقة أولًا."
        case .recoveryRestabilization:
            return "هذه خطة إعادة التثبيت، ترفع الماضي تدريجيًا مع إبقاء الضعيف حاضرًا يوميًا."
        }
    }
}

private struct QuranPlanSafeguardsCard: View {
    let plan: QuranAdaptiveDailyPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuranSectionHeader(
                title: "ضمانات اليوم",
                subtitle: "رسائل تحافظ على الاستمرار بدون ضغط زائد.",
                tint: quranModeTint(for: plan.mode),
                systemImage: "checkmark.shield"
            )

            ForEach(Array(plan.safeguards.enumerated()), id: \.offset) { _, safeguard in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .foregroundColor(quranModeTint(for: plan.mode))
                        .frame(width: 18)
                    Text(safeguard)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .aamalCardSolid()
    }
}

private struct QuranQiyamCard: View {
    let insight: QuranQiyamDailyInsight
    let isEnabled: Bool
    let startLocked: Bool
    let startSummary: String?
    let savedRangeSummary: String?
    @Binding var startSurahIndex: Int
    @Binding var startAyah: Int
    @Binding var stopSurahIndex: Int
    @Binding var stopAyah: Int
    let computedAyahCount: Int?
    let validationMessage: String?
    let saveAction: () -> Void
    let clearAction: () -> Bool
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("قيام الليل")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(isEnabled ? "اختياري اليوم، ويُحتسب كجلسة مراجعة رحيمة." : "الدمج متوقف الآن ويمكن تفعيله من الإعدادات.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let rank = insight.rank {
                    Label(rank.title, systemImage: rank.systemImage)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(qiyamTint(for: rank).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if isEnabled {
                QuranModeBanner(
                    title: insight.ayatCount == 0 ? "لا توجد جلسة محفوظة لهذه الليلة" : "تم تسجيل جلسة الليلة",
                    subtitle: insight.reducedAyahs > 0
                        ? "خفف القيام عنك \(insight.reducedAyahs) آية من عبء اليوم."
                        : "حتى الجلسة الخفيفة تحفظ السلسلة وتبقي الباب مفتوحًا.",
                    tint: qiyamBannerTint
                )

                if startLocked {
                    if let startSummary {
                        QuranModeBanner(
                            title: "الحساب يبدأ من آخر موضع محفوظ",
                            subtitle: startSummary,
                            tint: AamalTheme.emerald
                        )
                    }
                } else {
                    QuranAyahSelector(
                        title: "ابدأ المتابعة من",
                        surahIndex: $startSurahIndex,
                        ayah: $startAyah,
                        accent: AamalTheme.emerald
                    )
                }

                QuranAyahSelector(
                    title: "توقفت عند",
                    surahIndex: $stopSurahIndex,
                    ayah: $stopAyah,
                    accent: qiyamBannerTint
                )

                if let computedAyahCount {
                    QuranModeBanner(
                        title: "سيُحتسب لك تلقائيًا",
                        subtitle: "من نقطة البداية إلى موضع التوقف الحالي = \(computedAyahCount) آية.",
                        tint: AamalTheme.gold
                    )
                } else if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let savedRangeSummary {
                    Text("المدى المحفوظ اليوم: \(savedRangeSummary)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 10) {
                    QuranMetricPill(title: "سلسلة القيام", value: "\(insight.streak) يوم", accent: AamalTheme.emerald)
                    QuranMetricPill(title: "قراءة الليلة", value: insight.ayatCount == 0 ? "غير محفوظ" : "\(insight.ayatCount) آية", accent: qiyamBannerTint)
                    QuranMetricPill(title: "تخفيف اليوم", value: insight.reducedAyahs == 0 ? "0" : "\(insight.reducedAyahs) آية", accent: AamalTheme.gold)
                }

                if insight.reductionPercentage > 0 {
                    Text("التخفيف المحسوب اليوم: \(insight.reductionPercentage)% من عبء المراجعة، بحد أقصى 40%.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button(action: saveAction) {
                        Text("حفظ قراءة الليلة")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AamalTheme.ink)

                    Button(action: {
                        _ = clearAction()
                    }) {
                        Text("مسح")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AamalTheme.gold)
                    .disabled(insight.ayatCount == 0)
                }
            } else {
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button(action: openSettingsAction) {
                    Text("تفعيل دمج القيام")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AamalTheme.emerald)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            qiyamBannerTint.opacity(0.10),
                            AamalTheme.gold.opacity(0.06)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(qiyamBannerTint.opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.09), radius: 12, x: 0, y: 6)
        )
    }

    private var qiyamBannerTint: Color {
        if let rank = insight.rank {
            return qiyamTint(for: rank)
        }
        return insight.ayatCount > 0 ? AamalTheme.gold : AamalTheme.emerald
    }
}

private struct QuranAyahSelector: View {
    let title: String
    @Binding var surahIndex: Int
    @Binding var ayah: Int
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            Menu {
                ForEach(QuranAyahCatalog.surahs) { surah in
                    Button("سورة \(surah.name)") {
                        surahIndex = surah.index
                        ayah = min(ayah, surah.ayahCount)
                    }
                }
            } label: {
                HStack {
                    Text("السورة")
                    Spacer()
                    Text(selectedSurahTitle)
                        .foregroundColor(AamalTheme.ink)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(accent.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(accent.opacity(0.14), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("مرر لاختيار الآية")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("الآية", selection: ayahBinding) {
                    ForEach(1...selectedSurahAyahCount, id: \.self) { ayahNumber in
                        Text("آية \(ayahNumber)")
                            .tag(ayahNumber)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 120)
            }
        }
    }

    private var selectedSurahTitle: String {
        QuranAyahCatalog.surah(at: surahIndex)?.name ?? "غير محددة"
    }

    private var selectedSurahAyahCount: Int {
        QuranAyahCatalog.surah(at: surahIndex)?.ayahCount ?? 1
    }

    private var ayahBinding: Binding<Int> {
        Binding(
            get: { min(max(ayah, 1), selectedSurahAyahCount) },
            set: { ayah = min(max($0, 1), selectedSurahAyahCount) }
        )
    }
}

private extension QuranStrengthTier {
    var tint: Color {
        switch self {
        case .fragile:
            return AamalTheme.gold
        case .building:
            return AamalTheme.mint
        case .anchored:
            return AamalTheme.emerald
        case .unmemorized:
            return Color(.systemGray4)
        }
    }

    var systemImage: String {
        switch self {
        case .fragile:
            return "exclamationmark.triangle.fill"
        case .building:
            return "hammer.fill"
        case .anchored:
            return "checkmark.seal.fill"
        case .unmemorized:
            return "circle.dotted"
        }
    }
}

private struct QuranStrengthDistributionCard: View {
    @ObservedObject var store: TaskStore

    @State private var selectedRubIndex: Int?
    @State private var cachedComparison: QuranStrengthDistributionComparison?

    @State private var isMultiSelectMode: Bool = false
    @State private var selectedRubIndices: Set<Int> = []
    @State private var showBatchScoreSheet: Bool = false
    @State private var batchDraftScore: Double = 60

    private var comparison: QuranStrengthDistributionComparison {
        cachedComparison ?? store.todaysQuranStrengthComparison
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                QuranSectionHeader(
                    title: "خريطة قوة الحفظ",
                    subtitle: dashboardSubtitle,
                    tint: AamalTheme.emerald,
                    systemImage: "square.grid.3x3.fill"
                )

                Spacer()

                if isMultiSelectMode {
                    Button(action: exitMultiSelectMode) {
                        Text("تم")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .tint(AamalTheme.emerald)
                } else {
                    Button(action: { isMultiSelectMode = true }) {
                        Image(systemName: "checkmark.circle.badge.plus")
                            .font(.title3)
                    }
                    .tint(AamalTheme.emerald)
                    .accessibilityLabel("تحديد متعدد")
                }
            }

            if isMultiSelectMode, !selectedRubIndices.isEmpty {
                QuranModeBanner(
                    title: "\(selectedRubIndices.count) ربع محدد",
                    subtitle: "اضغط على الأرباع لإضافتها أو إزالتها، ثم اختر الإجراء أدناه.",
                    tint: AamalTheme.emerald
                )
            }

            if let focusSummary, !isMultiSelectMode {
                QuranModeBanner(
                    title: "أين يتركز الجهد الآن؟",
                    subtitle: focusSummary,
                    tint: AamalTheme.gold
                )
            }

            if unmemorizedCount > 0, !isMultiSelectMode {
                QuranModeBanner(
                    title: "الأرباع غير المحفوظة مطوية",
                    subtitle: "يوجد الآن \(unmemorizedCount) ربع خارج مقدار المحفوظ الحالي. بقيت في الخريطة العامة فقط، وأُزيلت من بطاقات القوة التفصيلية حتى لا تزحم اللوحة.",
                    tint: AamalTheme.ink.opacity(0.72)
                )
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(visibleLegendTiers, id: \.self) { tier in
                    QuranStrengthLegendCard(
                        tier: tier,
                        todayCount: comparison.today.count(for: tier),
                        lastWeekCount: comparison.lastWeek.count(for: tier),
                        total: memorizedRubTotal
                    )
                }
            }

            if let selectedTodaySample, !isMultiSelectMode {
                QuranStrengthRubDetailCard(
                    today: selectedTodaySample,
                    lastWeek: comparison.lastWeek.sample(for: selectedTodaySample.rub.globalRubIndex),
                    currentManualOverride: store.quranManualStrengthOverride(for: selectedTodaySample.rub),
                    saveManualOverride: { score in
                        if store.setQuranManualStrength(score, for: selectedTodaySample.rub) {
                            selectedRubIndex = selectedTodaySample.rub.globalRubIndex
                        }
                    },
                    clearManualOverride: {
                        _ = store.clearQuranManualStrength(selectedTodaySample.rub)
                    }
                )
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("التوزيع على كامل القرآن")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    if isMultiSelectMode {
                        Text("اضغط للتحديد")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("اضغط مطولًا للتحديد المتعدد")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(juzRows, id: \.juzNumber) { row in
                    HStack(spacing: 8) {
                        Text("ج\(row.juzNumber)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 28, alignment: .leading)

                        HStack(spacing: 4) {
                            ForEach(row.samples) { sample in
                                rubCell(for: sample)
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))

            if isMultiSelectMode, !selectedRubIndices.isEmpty {
                batchActionToolbar
            }
        }
        .aamalCardSolid()
        .onAppear {
            if cachedComparison == nil {
                cachedComparison = store.todaysQuranStrengthComparison
            }
        }
        .onChange(of: store.quranRevisionPlan.totalMemorizedRubs) { _, _ in
            cachedComparison = store.todaysQuranStrengthComparison
        }
        .onChange(of: store.quranRevisionPlan.weakRubIndices) { _, _ in
            cachedComparison = store.todaysQuranStrengthComparison
        }
        .onChange(of: store.quranRevisionPlan.manualStrengthOverrides) { _, _ in
            cachedComparison = store.todaysQuranStrengthComparison
        }
        .onChange(of: store.quranRevisionPlan.completedDates) { _, _ in
            cachedComparison = store.todaysQuranStrengthComparison
        }
        .onChange(of: store.quranRevisionPlan.qiyamSessions) { _, _ in
            cachedComparison = store.todaysQuranStrengthComparison
        }
        .sheet(isPresented: $showBatchScoreSheet) {
            batchScoreSheet
        }
    }

    @ViewBuilder
    private func rubCell(for sample: QuranRubStrengthSample) -> some View {
        let isSelected = selectedRubIndices.contains(sample.rub.globalRubIndex)
        let isActive = sample.rub.globalRubIndex == activeRubIndex

        Button(action: { handleRubTap(sample) }) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(sample.tier.tint.opacity(cellOpacity(for: sample)))
                    .frame(maxWidth: .infinity, minHeight: 14, maxHeight: 14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(
                                isMultiSelectMode && isSelected
                                    ? AamalTheme.emerald
                                    : (isActive ? AamalTheme.ink.opacity(0.7) : sample.tier.tint.opacity(0.16)),
                                lineWidth: (isMultiSelectMode && isSelected) || isActive ? 1.6 : 1
                            )
                    )

                if isMultiSelectMode && isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(1)
                        .background(AamalTheme.emerald)
                        .clipShape(Circle())
                        .offset(x: 2, y: -2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(sample.rub.detailedTitle) - \(sample.tier.title) - \(Int(sample.score.rounded()))٪")
        .onLongPressGesture(minimumDuration: 0.4) {
            if !isMultiSelectMode {
                isMultiSelectMode = true
                selectedRubIndices.insert(sample.rub.globalRubIndex)
            }
        }
    }

    private func handleRubTap(_ sample: QuranRubStrengthSample) {
        if isMultiSelectMode {
            if selectedRubIndices.contains(sample.rub.globalRubIndex) {
                selectedRubIndices.remove(sample.rub.globalRubIndex)
            } else {
                selectedRubIndices.insert(sample.rub.globalRubIndex)
            }
        } else {
            selectedRubIndex = sample.rub.globalRubIndex
        }
    }

    private func exitMultiSelectMode() {
        isMultiSelectMode = false
        selectedRubIndices.removeAll()
    }

    private var batchActionToolbar: some View {
        VStack(spacing: 10) {
            Divider()

            HStack(spacing: 8) {
                Button(action: applyBatchWeakMark) {
                    Label("وسم ضعف", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))

                Button(action: applyBatchClearWeak) {
                    Label("إزالة الوسم", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.mint))

                Button(action: { showBatchScoreSheet = true }) {
                    Label("تعيين درجة", systemImage: "slider.horizontal.3")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.emerald))

                Button(action: applyBatchClearScore) {
                    Label("إزالة الدرجة", systemImage: "xmark.circle.fill")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.ink.opacity(0.6)))
            }
        }
    }

    private var batchScoreSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("تعيين درجة يدوية لـ \(selectedRubIndices.count) ربع")
                    .font(.headline)

                Text("\(Int(batchDraftScore.rounded()))٪")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundColor(AamalTheme.emerald)

                Slider(value: $batchDraftScore, in: 0...100, step: 1)
                    .tint(AamalTheme.emerald)
                    .padding(.horizontal)

                HStack(spacing: 8) {
                    Button(action: { batchDraftScore = 30 }) {
                        Text("هش")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))

                    Button(action: { batchDraftScore = 60 }) {
                        Text("قيد التثبيت")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.mint))

                    Button(action: { batchDraftScore = 85 }) {
                        Text("راسخ")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.emerald))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("درجة جماعية")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { showBatchScoreSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        applyBatchScore()
                        showBatchScoreSheet = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func selectedRubs() -> [QuranRubReference] {
        selectedRubIndices.map { QuranRubReference(globalRubIndex: $0) }
    }

    private func applyBatchWeakMark() {
        store.batchMarkQuranRubWeak(selectedRubs())
        exitMultiSelectMode()
    }

    private func applyBatchClearWeak() {
        store.batchClearQuranRubWeak(for: selectedRubs())
        exitMultiSelectMode()
    }

    private func applyBatchScore() {
        store.batchSetQuranManualStrength(batchDraftScore, for: selectedRubs())
        exitMultiSelectMode()
    }

    private func applyBatchClearScore() {
        store.batchClearQuranManualStrength(for: selectedRubs())
        exitMultiSelectMode()
    }

    private var dashboardSubtitle: String {
        let memorizedCount = memorizedRubTotal
        guard memorizedCount > 0 else {
            return "ستتحول هذه الخريطة إلى توزيع حيّ بمجرد تحديد مقدار المحفوظ."
        }

        return "الدرجة هنا مبنية على نموذج استدعاء + ثبات: احتمال التذكر يهبط مع الزمن وفق منحنى نسيان أسي، وثبات الربع يرتفع كلما تكررت له مراجعات ناجحة متباعدة."
    }

    private var activeRubIndex: Int {
        if let selectedRubIndex,
           comparison.today.sample(for: selectedRubIndex)?.tier != .unmemorized {
            return selectedRubIndex
        }
        return suggestedSample?.rub.globalRubIndex ?? 1
    }

    private var selectedTodaySample: QuranRubStrengthSample? {
        comparison.today.sample(for: activeRubIndex)
    }

    private var visibleLegendTiers: [QuranStrengthTier] {
        QuranStrengthTier.allCases.filter { $0 != .unmemorized }
    }

    private var memorizedRubTotal: Int {
        max(1, comparison.today.samples.filter { $0.tier != .unmemorized }.count)
    }

    private var unmemorizedCount: Int {
        comparison.today.count(for: .unmemorized)
    }

    private var suggestedSample: QuranRubStrengthSample? {
        comparison.today.samples
            .filter { $0.tier != .unmemorized }
            .sorted { lhs, rhs in
                strengthPriority(for: lhs) < strengthPriority(for: rhs)
            }
            .first
    }

    private var juzRows: [(juzNumber: Int, samples: [QuranRubStrengthSample])] {
        let samples = comparison.today.samples
        return stride(from: 0, to: samples.count, by: 8).enumerated().map { offset, start in
            let end = min(start + 8, samples.count)
            return (juzNumber: offset + 1, samples: Array(samples[start..<end]))
        }
    }

    private var focusSummary: String? {
        guard let focusedRow = juzRows.max(by: { focusWeight(for: $0.samples) < focusWeight(for: $1.samples) }) else {
            return nil
        }

        let fragileCount = focusedRow.samples.filter { $0.tier == .fragile }.count
        let buildingCount = focusedRow.samples.filter { $0.tier == .building }.count
        let averageScore = Int((focusedRow.samples.map(\.score).reduce(0, +) / Double(focusedRow.samples.count)).rounded())
        guard fragileCount > 0 || buildingCount > 0 else { return nil }

        return "أثقل تركّزٍ الآن في الجزء \(focusedRow.juzNumber): فيه \(fragileCount) أرباع هشة و\(buildingCount) أرباع قيد التثبيت، ومتوسط الدرجة فيه \(averageScore)٪."
    }

    private func strengthPriority(for sample: QuranRubStrengthSample) -> (Int, Double, Int) {
        let urgency: Int
        if sample.isManuallyWeak {
            urgency = 0
        } else if sample.isInRecoveryToday {
            urgency = 1
        } else if sample.tier == .fragile {
            urgency = 2
        } else if sample.isDueToday {
            urgency = 3
        } else if sample.tier == .building {
            urgency = 4
        } else {
            urgency = 5
        }

        return (urgency, sample.score, sample.rub.globalRubIndex)
    }

    private func focusWeight(for samples: [QuranRubStrengthSample]) -> Int {
        samples.reduce(0) { partial, sample in
            switch sample.tier {
            case .fragile:
                return partial + 4
            case .building:
                return partial + 2
            case .anchored:
                return partial + (sample.isDueToday ? 1 : 0)
            case .unmemorized:
                return partial
            }
        }
    }

    private func cellOpacity(for sample: QuranRubStrengthSample) -> Double {
        guard sample.tier != .unmemorized else { return 0.30 }
        return min(0.95, max(0.45, 0.35 + (sample.score / 100) * 0.6))
    }
}

private struct QuranStrengthLegendCard: View {
    let tier: QuranStrengthTier
    let todayCount: Int
    let lastWeekCount: Int
    let total: Int

    private var delta: Int {
        todayCount - lastWeekCount
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: tier.systemImage)
                    .foregroundColor(tier.tint)
                Text(tier.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text(deltaLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("اليوم: \(todayCount) • قبل أسبوع: \(lastWeekCount)")
                .font(.headline)

            Text(tier.subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)

            VStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("اليوم")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(todayCount) / \(total)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(todayCount), total: Double(total))
                        .tint(tier.tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("قبل 7 أيام")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(lastWeekCount) / \(total)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    ProgressView(value: Double(lastWeekCount), total: Double(total))
                        .tint(tier.tint.opacity(0.55))
                }
            }
        }
        .padding(12)
        .background(tier.tint.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tier.tint.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var deltaLabel: String {
        let prefix = delta > 0 ? "+" : ""
        return "Δ \(prefix)\(delta)"
    }
}

private struct QuranStrengthRubDetailCard: View {
    let today: QuranRubStrengthSample
    let lastWeek: QuranRubStrengthSample?
    let currentManualOverride: Double?
    let saveManualOverride: (Double) -> Void
    let clearManualOverride: () -> Void

    @State private var draftManualScore: Double

    init(
        today: QuranRubStrengthSample,
        lastWeek: QuranRubStrengthSample?,
        currentManualOverride: Double?,
        saveManualOverride: @escaping (Double) -> Void,
        clearManualOverride: @escaping () -> Void
    ) {
        self.today = today
        self.lastWeek = lastWeek
        self.currentManualOverride = currentManualOverride
        self.saveManualOverride = saveManualOverride
        self.clearManualOverride = clearManualOverride
        _draftManualScore = State(initialValue: currentManualOverride ?? today.score)
    }

    private var scoreDelta: Int {
        Int((today.score - (lastWeek?.score ?? today.score)).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(today.rub.detailedTitle)
                        .font(.headline)
                    Text(today.rub.spanSummary.isEmpty ? today.rub.pageSpanText : today.rub.spanSummary)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                QuranStatusBadge(
                    title: today.tier.title,
                    systemImage: today.tier.systemImage,
                    tint: today.tier.tint
                )
            }

            HStack(spacing: 10) {
                QuranMetricPill(title: "درجة اليوم", value: "\(Int(today.score.rounded()))٪", accent: today.tier.tint)
                QuranMetricPill(title: "التغير عن الأسبوع", value: deltaLabel, accent: scoreDelta >= 0 ? AamalTheme.emerald : AamalTheme.gold)
                QuranMetricPill(title: "ثبات متوقع", value: "\(Int(today.stabilityDays.rounded())) يوم", accent: AamalTheme.ink.opacity(0.78))
                QuranMetricPill(title: "مرات مرصودة", value: "\(today.reviewCount)", accent: AamalTheme.mint)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("الحالة الحالية وسببها")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(today.weaknessReason.title)
                    .font(.subheadline)
                    .foregroundColor(today.tier.tint)
                Text(today.weaknessDetail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 8) {
                if today.isManuallyWeak {
                    QuranStatusBadge(title: "وسم يدوي", systemImage: "hand.point.up.left.fill", tint: AamalTheme.gold)
                }
                if currentManualOverride != nil {
                    QuranStatusBadge(title: "درجة يدوية", systemImage: "slider.horizontal.3", tint: AamalTheme.emerald)
                }
                if today.isInRecoveryToday {
                    QuranStatusBadge(title: "استرجاع اليوم", systemImage: "arrow.uturn.backward.circle.fill", tint: AamalTheme.gold)
                }
                if today.isDueToday {
                    QuranStatusBadge(title: "مطلوب اليوم", systemImage: "calendar.badge.clock", tint: AamalTheme.mint)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("تعديل القوة يدويًا")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(Int(draftManualScore.rounded()))٪")
                        .font(.subheadline)
                        .foregroundColor(AamalTheme.emerald)
                }

                Slider(value: $draftManualScore, in: 0...100, step: 1)
                    .tint(AamalTheme.emerald)

                HStack(spacing: 8) {
                    Button(action: { draftManualScore = 30 }) {
                        Text("هش")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))

                    Button(action: { draftManualScore = 60 }) {
                        Text("قيد التثبيت")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.mint))

                    Button(action: { draftManualScore = 85 }) {
                        Text("راسخ")
                    }
                    .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.emerald))
                }

                HStack(spacing: 10) {
                    Button(action: { saveManualOverride(draftManualScore) }) {
                        Text(currentManualOverride == nil ? "حفظ الدرجة اليدوية" : "تحديث الدرجة اليدوية")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AamalSecondaryButtonStyle(tint: AamalTheme.emerald))

                    Button(action: {
                        draftManualScore = today.score
                        clearManualOverride()
                    }) {
                        Text("إزالة التعديل")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AamalSecondaryButtonStyle(tint: AamalTheme.gold))
                    .disabled(currentManualOverride == nil)
                }
            }

            Text(lastReviewText)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .onChange(of: today.id) { _, _ in
            draftManualScore = currentManualOverride ?? today.score
        }
        .onChange(of: currentManualOverride) { _, newValue in
            draftManualScore = newValue ?? today.score
        }
    }

    private var deltaLabel: String {
        let prefix = scoreDelta > 0 ? "+" : ""
        return "\(prefix)\(scoreDelta)٪"
    }

    private var lastReviewText: String {
        if let lastReviewDate = today.lastReviewDate {
            return "آخر مراجعة مرصودة: \(formattedDate(lastReviewDate))"
        }
        return "لا توجد مراجعة مرصودة لهذا الربع داخل التطبيق بعد."
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

private struct QuranWeakSpotsDashboardCard: View {
    let plan: QuranAdaptiveDailyPlan
    let weakRubs: [QuranRubReference]
    let clearWeakAction: (QuranRubReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuranSectionHeader(
                title: "لوحة الضعف",
                subtitle: dashboardSubtitle,
                tint: AamalTheme.gold,
                systemImage: "waveform.path.ecg"
            )

            HStack(spacing: 10) {
                QuranMetricPill(title: "المواضع المعلّمة", value: "\(weakRubs.count)", accent: AamalTheme.gold)
                QuranMetricPill(title: "استرجاع اليوم", value: recoveryAyahSummary, accent: AamalTheme.emerald)
                QuranMetricPill(title: "صلوات متأثرة", value: "\(prayersWithWeakFocus.count)", accent: AamalTheme.ink.opacity(0.82))
            }

            if !prayersWithWeakFocus.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("أين يظهر الضعف اليوم؟")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(prayersWithWeakFocus) { highlight in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: highlight.prayer.systemImage)
                                .foregroundColor(AamalTheme.gold)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(highlight.prayer.arabicName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(highlight.summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text("\(highlight.estimatedAyahs) آية")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(AamalTheme.gold.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }

            if priorityWeakRubs.isEmpty {
                Text("لا توجد مواضع موسومة يدويًا الآن. إذا تكرر التعثر في موضع ما فوسمه من بطاقة توزيع الصلوات ليظهر هنا مباشرة.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AamalTheme.emerald.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("أولوية المتابعة")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    ForEach(priorityWeakRubs) { rub in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(rub.detailedTitle)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text(rub.spanSummary.isEmpty ? rub.pageSpanText : rub.spanSummary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(priorityLabel(for: rub))
                                    .font(.caption2)
                                    .foregroundColor(AamalTheme.gold)
                            }

                            Spacer()

                            Button(action: { clearWeakAction(rub) }) {
                                Text("إزالة الوسم")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(AamalTheme.emerald)
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                }
            }
        }
        .aamalCard()
    }

    private var recoveryAyahSummary: String {
        guard let recoveryItem = plan.requiredRevision.first(where: { $0.kind == .recovery }) else {
            return "0"
        }

        return "\(recoveryItem.estimatedAyahs) آية"
    }

    private var dashboardSubtitle: String {
        if weakRubs.isEmpty, prayersWithWeakFocus.isEmpty {
            return "لا توجد بؤر ضعف صريحة اليوم، لكن وسم أي موضع متعثر سيُظهره هنا فورًا."
        }

        if let recoveryItem = plan.requiredRevision.first(where: { $0.kind == .recovery }) {
            return "هذه اللوحة تختصر مواضع الاسترجاع والوسوم اليدوية حتى ترى أين يحتاج المحفوظ إلى عناية مباشرة اليوم. بند الاسترجاع الحالي حوالي \(recoveryItem.estimatedAyahs) آية."
        }

        return "هذه اللوحة تجمع المواضع المعلّمة ضعيفة وتُظهر أين تدخل داخل خطة اليوم."
    }

    private var prayersWithWeakFocus: [QuranWeakPrayerHighlight] {
        plan.prayerAssignments.compactMap { assignment in
            let segments = assignment.segments.filter { segment in
                segment.kind == .recovery || weakRubs.contains(where: { $0.globalRubIndex == segment.rub.globalRubIndex })
            }

            guard !segments.isEmpty else { return nil }

            let rubTitles = Array(Set(segments.map { $0.rub.shortTitle })).sorted()
            let summary = rubTitles.prefix(2).joined(separator: "، ")
            return QuranWeakPrayerHighlight(
                prayer: assignment.prayer,
                summary: segments.contains(where: { $0.kind == .recovery })
                    ? "يبدأ هنا مسار الاسترجاع مع \(summary.isEmpty ? "مقاطع ضعيفة" : summary)."
                    : "تحتاج هذه الصلاة تركيزًا خاصًا على \(summary).",
                estimatedAyahs: segments.reduce(0) { $0 + $1.estimatedAyahs }
            )
        }
    }

    private var priorityWeakRubs: [QuranRubReference] {
        var seen: Set<Int> = []
        let scheduledWeak = plan.prayerAssignments
            .flatMap(\.segments)
            .filter { segment in
                segment.kind == .recovery || weakRubs.contains(where: { $0.globalRubIndex == segment.rub.globalRubIndex })
            }
            .map(\.rub)

        return (scheduledWeak + weakRubs).compactMap { rub in
            guard !seen.contains(rub.globalRubIndex) else { return nil }
            seen.insert(rub.globalRubIndex)
            return rub
        }
        .prefix(4)
        .map { $0 }
    }

    private func priorityLabel(for rub: QuranRubReference) -> String {
        if let prayer = plan.prayerAssignments.first(where: { assignment in
            assignment.segments.contains(where: { $0.rub.globalRubIndex == rub.globalRubIndex })
        })?.prayer {
            return "مجدول اليوم في \(prayer.arabicName)."
        }

        return "معلَّم يدويًا وسيعود إلى الاسترجاع حتى إزالة الوسم."
    }
}

private struct QuranWeakPrayerHighlight: Identifiable {
    let prayer: PrayerCompensationType
    let summary: String
    let estimatedAyahs: Int

    var id: PrayerCompensationType { prayer }
}

private struct QuranMarkedWeakCard: View {
    let rubs: [QuranRubReference]
    let clearWeakAction: (QuranRubReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("المواضع المعلّمة ضعيفة")
                .font(.headline)

            Text("أي موضع هنا يدخل تلقائيًا في بند الاسترجاع حتى تزيل الوسم يدويًا.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(rubs) { rub in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                        .foregroundColor(AamalTheme.gold)
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rub.detailedTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(rub.spanSummary.isEmpty ? rub.pageSpanText : rub.spanSummary)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: { clearWeakAction(rub) }) {
                        Text("إزالة الوسم")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(AamalTheme.emerald)
                }
                .padding(12)
                .background(AamalTheme.gold.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .aamalCard()
    }
}

private struct QuranPrayerDistributionCard: View {
    @ObservedObject var store: TaskStore
    let plan: QuranAdaptiveDailyPlan
    let toggleWeakAction: (QuranRubReference) -> Void
    let prayerLogAction: (PrayerCompensationType) -> Void
    let completionAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            QuranSectionHeader(
                title: "توزيع المراجعة على الصلوات",
                subtitle: prayerSubtitle,
                tint: quranModeTint(for: plan.mode),
                systemImage: "sun.and.horizon"
            )

            ForEach(plan.prayerAssignments) { assignment in
                QuranPrayerAssignmentCard(
                    assignment: assignment,
                    weakRubIDs: weakRubIDs,
                    isLogged: store.isQuranPrayerCompleted(assignment.prayer),
                    toggleWeakAction: toggleWeakAction,
                    logAction: prayerLogAction
                )
            }

            Button(action: completionAction) {
                Text(store.isQuranRevisionCompleted() ? "خطة اليوم مكتملة" : "تسجيل اليوم دفعة واحدة")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.gold)
            .disabled(store.isQuranRevisionCompleted() || plan.requiredRevision.isEmpty)

            Text("يمكنك تسجيل كل صلاة وحدها، وعند اكتمال الصلوات المفعلة تُحتسب الخطة كاملة تلقائيًا. الإنجاز الكامل يمنحك \(store.quranRevisionPlan.dailyGoalRubs * 6) نقطة.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .aamalCardSolid()
    }

    private var weakRubIDs: Set<Int> {
        Set(store.quranMarkedWeakRubs.map(\.globalRubIndex))
    }

    private var prayerSubtitle: String {
        switch plan.mode {
        case .normal:
            return "السعة هنا تقريبية بالآيات، والتوزيع يقدم المقاطع الأضعف والأثقل في أول اليوم."
        case .reducedSafety:
            return "كل صلاة مفعلة تحمل جرعة قصيرة تحافظ على الاستمرارية بدل إسقاط اليوم كاملًا."
        case .recoveryReentry, .recoveryRestabilization:
            return "التوزيع هنا جزء من بروتوكول الاستعادة، لذلك لن يعود مباشرة إلى الحجم المعتاد حتى يثبت المحفوظ."
        }
    }
}

private struct QuranPrayerAssignmentCard: View {
    let assignment: QuranPrayerAssignment
    let weakRubIDs: Set<Int>
    let isLogged: Bool
    let toggleWeakAction: (QuranRubReference) -> Void
    let logAction: (PrayerCompensationType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(assignment.prayer.arabicName, systemImage: assignment.prayer.systemImage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                if isLogged {
                    QuranStatusBadge(title: "مسجلة", systemImage: "checkmark.circle.fill", tint: AamalTheme.emerald)
                }
                Text(assignment.capacityAyahs == 0
                    ? "غير مفعل"
                    : "\(assignment.assignedAyahs)/\(assignment.capacityAyahs) آية")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if condensedSegments.isEmpty {
                Text(assignment.capacityAyahs == 0
                    ? "هذه الصلاة غير مفعلة في سعة اليوم."
                    : "لا يوجد مقطع مخصص هنا اليوم.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(condensedSegments) { segment in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: segment.kind.systemImage)
                            .foregroundColor(quranTint(for: segment.kind))
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(segment.kind.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text(segment.detailText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(action: { toggleWeakAction(segment.rub) }) {
                                Label(
                                    weakRubIDs.contains(segment.rub.globalRubIndex) ? "إزالة الوسم" : "وسم بالضعف",
                                    systemImage: weakRubIDs.contains(segment.rub.globalRubIndex) ? "checkmark.circle" : "exclamationmark.triangle"
                                )
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.mini)
                            .tint(weakRubIDs.contains(segment.rub.globalRubIndex) ? AamalTheme.emerald : AamalTheme.gold)
                        }

                        Spacer()

                        Text("~\(segment.estimatedAyahs)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Group {
                    if isLogged {
                        Button(action: { }) {
                            Text("تم تسجيل هذه الصلاة")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AamalSecondaryButtonStyle(tint: AamalTheme.emerald))
                        .disabled(true)
                    } else {
                        Button(action: { logAction(assignment.prayer) }) {
                            Text("تسجيل هذه الصلاة")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AamalPrimaryButtonStyle(tint: AamalTheme.emerald))
                    }
                }
            }
        }
        .padding(12)
        .background(quranTint(for: assignment.primaryKind ?? .pastRevision).opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var condensedSegments: [QuranPlanPageSlice] {
        guard let first = assignment.segments.first else { return [] }

        var merged: [QuranPlanPageSlice] = [first]
        for segment in assignment.segments.dropFirst() {
            if let last = merged.last,
               last.kind == segment.kind,
               last.rub == segment.rub,
               segment.startPage == last.endPage + 1 {
                merged.removeLast()
                merged.append(
                    QuranPlanPageSlice(
                        kind: last.kind,
                        rub: last.rub,
                        startPage: last.startPage,
                        endPage: segment.endPage,
                        estimatedAyahs: last.estimatedAyahs + segment.estimatedAyahs
                    )
                )
            } else {
                merged.append(segment)
            }
        }

        return merged
    }
}

private struct QuranAdaptiveSettingsCard: View {
    @Binding var juzCount: Int
    @Binding var additionalHizb: Int
    @Binding var additionalRub: Int
    @Binding var dailyGoalRubs: Int
    @Binding var recentWindowRubs: Int
    @Binding var newMemorizationTargetRubs: Int
    @Binding var qiyamEnabled: Bool
    @Binding var fajrCapacity: Int
    @Binding var dhuhrCapacity: Int
    @Binding var asrCapacity: Int
    @Binding var maghribCapacity: Int
    @Binding var ishaCapacity: Int
    let totalDraftRubs: Int
    let saveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("إعداد خطة الحفظ")
                .font(.headline)

            Text("هذه الإعدادات تحدد حد الأمان اليومي، نافذة السبقي، وسعة كل صلاة حتى يبني التطبيق خطة واضحة بلا تفكير إضافي.")
                .font(.caption)
                .foregroundColor(.secondary)

            QuranNumericControlRow(title: "الأجزاء المحفوظة", value: $juzCount, range: 0...30)

            QuranNumericControlRow(title: "الزيادة بالأحزاب", value: $additionalHizb, range: 0...maxAdditionalHizb)
                .disabled(juzCount == 30)

            QuranNumericControlRow(title: "الزيادة بالأرباع", value: $additionalRub, range: 0...maxAdditionalRub)
                .disabled(juzCount == 30 && additionalHizb == 0)

            Divider()

            Text("الأهداف التكيفية")
                .font(.subheadline)
                .fontWeight(.semibold)

            QuranNumericControlRow(title: "حد المراجعة اليومي", value: $dailyGoalRubs, range: 1...12, suffix: "ربع")
            QuranNumericControlRow(title: "نافذة السبقي", value: $recentWindowRubs, range: 1...maxRecentWindow, suffix: "ربع")
            QuranNumericControlRow(title: "هدف الحفظ الجديد", value: $newMemorizationTargetRubs, range: 0...maxNewTarget, suffix: "ربع")

            Toggle("دمج قيام الليل في الخطة", isOn: $qiyamEnabled)
                .tint(AamalTheme.emerald)

            Divider()

            Text("سعة الصلوات")
                .font(.subheadline)
                .fontWeight(.semibold)

            QuranNumericControlRow(title: "سعة الفجر", value: $fajrCapacity, range: 0...40, suffix: "آية")
            QuranNumericControlRow(title: "سعة الظهر", value: $dhuhrCapacity, range: 0...40, suffix: "آية")
            QuranNumericControlRow(title: "سعة العصر", value: $asrCapacity, range: 0...40, suffix: "آية")
            QuranNumericControlRow(title: "سعة المغرب", value: $maghribCapacity, range: 0...40, suffix: "آية")
            QuranNumericControlRow(title: "سعة العشاء", value: $ishaCapacity, range: 0...40, suffix: "آية")

            Text("المحفوظ الحالي: \(quranDescribe(totalRubs: totalDraftRubs))")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("الجديد يتوقف تلقائيًا إذا ضعفت المراجعة أو تجاوز الحمل سعتك اليومية.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: saveAction) {
                Text("حفظ خطة اليوم")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.emerald)
        }
        .onChange(of: juzCount) { _, newValue in
            if newValue == 30 {
                additionalHizb = 0
                additionalRub = 0
            }
            additionalHizb = min(additionalHizb, maxAdditionalHizb)
            additionalRub = min(additionalRub, maxAdditionalRub)
            recentWindowRubs = min(recentWindowRubs, maxRecentWindow)
            newMemorizationTargetRubs = min(newMemorizationTargetRubs, maxNewTarget)
        }
        .onChange(of: additionalHizb) { _, _ in
            additionalRub = min(additionalRub, maxAdditionalRub)
            recentWindowRubs = min(recentWindowRubs, maxRecentWindow)
            newMemorizationTargetRubs = min(newMemorizationTargetRubs, maxNewTarget)
        }
        .aamalCard()
    }

    private var maxAdditionalHizb: Int {
        juzCount == 30 ? 0 : 1
    }

    private var maxAdditionalRub: Int {
        if juzCount == 30 && additionalHizb == 0 {
            return 0
        }
        return 3
    }

    private var maxRecentWindow: Int {
        max(1, min(totalDraftRubs == 0 ? 16 : totalDraftRubs, 16))
    }

    private var maxNewTarget: Int {
        totalDraftRubs >= 240 ? 0 : 2
    }
}

private struct QuranMetricPill: View {
    let title: String
    let value: String
    var accent: Color = AamalTheme.gold

    var body: some View {
        AamalStatPill(title: title, value: value, tint: accent)
    }
}

private struct QuranSectionHeader: View {
    let title: String
    let subtitle: String
    let tint: Color
    let systemImage: String

    var body: some View {
        AamalSectionHeader(title: title, subtitle: subtitle, tint: tint, systemImage: systemImage)
    }
}

private struct QuranStatusBadge: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(AamalTheme.tonalBackground(for: tint))
                    .overlay(
                        Capsule()
                            .stroke(tint.opacity(0.16), lineWidth: 1)
                    )
            )
            .clipShape(Capsule())
    }
}

private struct QuranModeBanner: View {
    let title: String
    let subtitle: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AamalTheme.tonalBackground(for: tint))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(tint.opacity(0.14), lineWidth: 1)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct QuranNumericControlRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var suffix: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                TextField("0", value: clampedBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 72)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(AamalTheme.gold.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Stepper(value: clampedBinding, in: range) {
                Text(suffix.isEmpty ? "القيمة الحالية: \(value)" : "القيمة الحالية: \(value) \(suffix)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var clampedBinding: Binding<Int> {
        Binding(
            get: { min(max(value, range.lowerBound), range.upperBound) },
            set: { value = min(max($0, range.lowerBound), range.upperBound) }
        )
    }
}

private func quranDescribe(totalRubs: Int) -> String {
    guard totalRubs > 0 else { return "غير محدد" }
    let juz = totalRubs / 8
    let remainder = totalRubs % 8
    let hizb = remainder / 4
    let rub = remainder % 4

    var parts: [String] = []
    if juz > 0 { parts.append("\(juz) جزء") }
    if hizb > 0 { parts.append("\(hizb) حزب") }
    if rub > 0 { parts.append("\(rub) ربع") }
    return parts.joined(separator: " + ")
}

private func quranPageSummary(for rubs: [QuranRubReference]) -> String {
    guard let firstMetadata = rubs.first?.metadata,
          let lastMetadata = rubs.last?.metadata else {
        return ""
    }

    if firstMetadata.startPage == lastMetadata.endPage {
        return "صفحة \(firstMetadata.startPage)"
    }

    return "من صفحة \(firstMetadata.startPage) إلى صفحة \(lastMetadata.endPage)"
}

private func quranTint(for kind: QuranPlanSegmentKind) -> Color {
    switch kind {
    case .newMemorization:
        return AamalTheme.emerald
    case .recovery:
        return AamalTheme.gold
    case .recentRevision:
        return AamalTheme.ink
    case .pastRevision:
        return AamalTheme.sand
    case .reinforcement:
        return AamalTheme.mint
    }
}

private func quranModeTint(for mode: QuranAdaptiveMode) -> Color {
    switch mode {
    case .normal:
        return AamalTheme.emerald
    case .reducedSafety:
        return AamalTheme.gold
    case .recoveryReentry:
        return AamalTheme.ink
    case .recoveryRestabilization:
        return AamalTheme.mint
    }
}

private extension QuranAdaptiveMode {
    var shortTitle: String {
        switch self {
        case .normal:
            return "استقرار"
        case .reducedSafety:
            return "وقاية"
        case .recoveryReentry:
            return "عودة"
        case .recoveryRestabilization:
            return "تثبيت"
        }
    }
}

private func qiyamTint(for rank: QuranQiyamRank) -> Color {
    switch rank {
    case .preservedConnection:
        return AamalTheme.emerald
    case .qanit:
        return AamalTheme.gold
    case .muqantir:
        return AamalTheme.ink
    }
}