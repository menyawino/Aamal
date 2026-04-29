import SwiftUI

private enum QuranQiyamInputMode: String, CaseIterable, Identifiable {
    case ayahs
    case pages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ayahs:
            return "عدد الآيات"
        case .pages:
            return "عدد الصفحات"
        }
    }
}

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
    @State private var qiyamInputMode: QuranQiyamInputMode = .ayahs
    @State private var qiyamAyatInput: Int
    @State private var qiyamPageInput: Int
    @State private var feedbackMessage: String = ""
    @State private var showSettingsSheet = false

    init(store: TaskStore) {
        self.store = store

        let totalRubs = store.quranRevisionPlan.totalMemorizedRubs
        let currentQiyamAyahs = store.todaysQiyamSession?.ayatCount ?? 0
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
        _qiyamAyatInput = State(initialValue: currentQiyamAyahs)
        _qiyamPageInput = State(initialValue: currentQiyamAyahs == 0 ? 0 : Int(ceil(Double(currentQiyamAyahs) / Double(QiyamSession.estimatedAyahsPerPage))))
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
                VStack(spacing: 16) {
                    QuranAdaptiveHeroCard(
                        store: store,
                        plan: todaysPlan,
                        openSettingsAction: { showSettingsSheet = true }
                    )

                    if !feedbackMessage.isEmpty {
                        Text(feedbackMessage)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(AamalTheme.emerald)
                            .aamalCard()
                    }

                    QuranQiyamCard(
                        insight: todaysPlan.qiyamInsight,
                        isEnabled: qiyamEnabled,
                        inputMode: $qiyamInputMode,
                        ayatInput: $qiyamAyatInput,
                        pageInput: $qiyamPageInput,
                        saveAction: saveQiyam,
                        clearAction: clearQiyam,
                        openSettingsAction: { showSettingsSheet = true }
                    )

                    if let newItem = todaysPlan.newMemorization {
                        QuranNewMemorizationCard(item: newItem)
                    }

                    QuranRequiredRevisionCard(plan: todaysPlan)

                    if !store.quranMarkedWeakRubs.isEmpty {
                        QuranMarkedWeakCard(
                            rubs: store.quranMarkedWeakRubs,
                            clearWeakAction: clearWeakRub
                        )
                    }

                    if !todaysPlan.safeguards.isEmpty {
                        QuranPlanSafeguardsCard(plan: todaysPlan)
                    }

                    QuranPrayerDistributionCard(
                        store: store,
                        plan: todaysPlan,
                        toggleWeakAction: toggleWeakRub,
                        completionAction: markTodayCompleted
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("إعدادات خطة الحفظ")
                }
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("خطة الحفظ")
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
                .background(AamalTheme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("إعدادات الخطة")
                .navigationBarTitleDisplayMode(.inline)
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
        qiyamAyatInput = store.todaysQiyamSession?.ayatCount ?? 0
        qiyamPageInput = qiyamAyatInput == 0 ? 0 : Int(ceil(Double(qiyamAyatInput) / Double(QiyamSession.estimatedAyahsPerPage)))
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
        let ayatCount = draftQiyamAyatCount
        if ayatCount == 0 {
            feedbackMessage = clearQiyam() ? "تم مسح إدخال قيام الليل لليوم." : "أدخل عددًا تقريبيًا للآيات أو الصفحات أولًا."
            return
        }

        let didSave = store.logQiyamSession(ayatCount: ayatCount)
        if didSave {
            qiyamAyatInput = ayatCount
            qiyamPageInput = Int(ceil(Double(ayatCount) / Double(QiyamSession.estimatedAyahsPerPage)))
            feedbackMessage = "تم حفظ قراءة قيام الليل ودمجها في خطة اليوم."
        } else {
            feedbackMessage = "تعذر حفظ قيام الليل. تحقق من تفعيل الدمج من الإعدادات."
        }
    }

    @discardableResult
    private func clearQiyam() -> Bool {
        let didClear = store.clearQiyamSession()
        if didClear {
            qiyamAyatInput = 0
            qiyamPageInput = 0
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

    private var draftQiyamAyatCount: Int {
        switch qiyamInputMode {
        case .ayahs:
            return min(max(0, qiyamAyatInput), 2000)
        case .pages:
            return min(max(0, qiyamPageInput), 100) * QiyamSession.estimatedAyahsPerPage
        }
    }
}

private struct QuranAdaptiveHeroCard: View {
    @ObservedObject var store: TaskStore
    let plan: QuranAdaptiveDailyPlan
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
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
                    .buttonStyle(.bordered)
                    .tint(AamalTheme.gold)
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
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.systemBackground),
                            quranModeTint(for: plan.mode).opacity(0.08),
                            AamalTheme.mint.opacity(0.18)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22)
                        .stroke(quranModeTint(for: plan.mode).opacity(0.18), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 14, x: 0, y: 8)
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
    @Binding var inputMode: QuranQiyamInputMode
    @Binding var ayatInput: Int
    @Binding var pageInput: Int
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

                Picker("نوع الإدخال", selection: $inputMode) {
                    ForEach(QuranQiyamInputMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if inputMode == .ayahs {
                    QuranNumericControlRow(title: "قرأت تقريبًا", value: $ayatInput, range: 0...2000, suffix: "آية")
                } else {
                    QuranNumericControlRow(title: "قرأت تقريبًا", value: $pageInput, range: 0...100, suffix: "صفحة")
                }

                HStack(spacing: 10) {
                    QuranMetricPill(title: "سلسلة القيام", value: "\(insight.streak) يوم", accent: AamalTheme.emerald)
                    QuranMetricPill(title: "قراءة الليلة", value: insight.ayatCount == 0 ? "غير محفوظ" : "\(insight.ayatCount) آية", accent: qiyamBannerTint)
                    QuranMetricPill(title: "تخفيف اليوم", value: insight.reducedAyahs == 0 ? "0" : "\(insight.reducedAyahs) آية", accent: AamalTheme.gold)
                }

                if inputMode == .pages {
                    Text("\(pageInput) صفحات ≈ \(pageInput * QiyamSession.estimatedAyahsPerPage) آية")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                    toggleWeakAction: toggleWeakAction
                )
            }

            Button(action: completionAction) {
                Text(store.isQuranRevisionCompleted() ? "خطة اليوم مكتملة" : "تسجيل إنجاز خطة اليوم")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.gold)
            .disabled(store.isQuranRevisionCompleted() || plan.requiredRevision.isEmpty)

            Text("إكمال الخطة اليوم يمنحك \(store.quranRevisionPlan.dailyGoalRubs * 6) نقطة.")
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
    let toggleWeakAction: (QuranRubReference) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(assignment.prayer.arabicName, systemImage: assignment.prayer.systemImage)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
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
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline)
                .foregroundColor(AamalTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(accent.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(accent.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct QuranSectionHeader: View {
    let title: String
    let subtitle: String
    let tint: Color
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundColor(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
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
            .background(tint.opacity(0.12))
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
        .background(tint.opacity(0.10))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.14), lineWidth: 1)
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