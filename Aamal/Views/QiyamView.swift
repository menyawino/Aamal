import SwiftUI

struct QiyamView: View {
    @ObservedObject var store: TaskStore

    @State private var qiyamStartSurahIndex: Int
    @State private var qiyamStartAyah: Int
    @State private var qiyamStopSurahIndex: Int
    @State private var qiyamStopAyah: Int
    @State private var feedbackMessage: String = ""
    @State private var showSettingsSheet = false

    init(store: TaskStore) {
        self.store = store

        let qiyamStartReference = store.todaysQiyamSession?.startAyah
            ?? store.qiyamLoggingStartReference()
            ?? QuranAyahCatalog.reference(surahIndex: 1, ayah: 1)
        let qiyamStopReference = store.todaysQiyamSession?.endAyah ?? qiyamStartReference

        _qiyamStartSurahIndex = State(initialValue: qiyamStartReference?.surahIndex ?? 1)
        _qiyamStartAyah = State(initialValue: qiyamStartReference?.ayah ?? 1)
        _qiyamStopSurahIndex = State(initialValue: qiyamStopReference?.surahIndex ?? 1)
        _qiyamStopAyah = State(initialValue: qiyamStopReference?.ayah ?? 1)
    }

    private var todaysPlan: QuranAdaptiveDailyPlan {
        store.todaysAdaptiveQuranPlan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AamalTheme.screenSpacing) {
                    if !feedbackMessage.isEmpty {
                        AamalSectionHeader(
                            title: "تم التحديث",
                            subtitle: feedbackMessage,
                            tint: AamalTheme.emerald,
                            systemImage: "checkmark.circle.fill"
                        )
                        .aamalCard()
                        .transition(AamalTransition.banner)
                    }

                    QuranQiyamCard(
                        insight: todaysPlan.qiyamInsight,
                        isEnabled: store.quranRevisionPlan.qiyamEnabled,
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

                    QiyamHistoryCard(store: store)

                    QiyamStatsCard(store: store)
                }
                .padding(.horizontal, AamalTheme.sectionSpacing)
                .padding(.bottom, AamalTheme.screenBottomInset)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("إعدادات القيام")
                }
            }
            .navigationTitle("قيام الليل")
            .navigationBarTitleDisplayMode(.inline)
            .aamalScreen()
        }
        .onAppear(perform: syncDraftFromStore)
        .sheet(isPresented: $showSettingsSheet) {
            QiyamSettingsSheet(store: store, isPresented: $showSettingsSheet)
        }
    }

    private func syncDraftFromStore() {
        let qiyamStartReference = store.todaysQiyamSession?.startAyah
            ?? store.qiyamLoggingStartReference()
            ?? QuranAyahCatalog.reference(surahIndex: 1, ayah: 1)
        let qiyamStopReference = store.todaysQiyamSession?.endAyah ?? qiyamStartReference
        qiyamStartSurahIndex = qiyamStartReference?.surahIndex ?? 1
        qiyamStartAyah = qiyamStartReference?.ayah ?? 1
        qiyamStopSurahIndex = qiyamStopReference?.surahIndex ?? qiyamStartSurahIndex
        qiyamStopAyah = qiyamStopReference?.ayah ?? qiyamStartAyah
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
            feedbackMessage = "تم مسح جلسة الليلة."
            syncDraftFromStore()
        }
        return didClear
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
        guard store.quranRevisionPlan.qiyamEnabled else { return nil }
        guard draftQiyamAyahCount == nil else { return nil }
        return "يجب أن تكون آية التوقف بعد نقطة البداية حتى يحسب التطبيق مقدار القراءة."
    }
}

private struct QiyamHistoryCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuranSectionHeader(
                title: "سجل القيام",
                subtitle: "آخر 7 جلسات مسجلة.",
                tint: AamalTheme.ink.opacity(0.8),
                systemImage: "clock.arrow.circlepath"
            )

            let sessions = store.quranRevisionPlan.qiyamSessions.suffix(7).reversed()
            if sessions.isEmpty {
                Text("لا توجد جلسات مسجلة بعد. ابدأ بتسجيل قراءة الليلة أعلاه.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(sessions.enumerated()), id: \.offset) { _, session in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.date, style: .date)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if let summary = session.rangeSummary {
                                Text(summary)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        Text("\(session.ayatCount) آية")
                            .font(.subheadline)
                            .foregroundColor(AamalTheme.emerald)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .aamalCardSolid()
    }
}

private struct QiyamStatsCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            QuranSectionHeader(
                title: "إحصائيات القيام",
                subtitle: "ملخص أداء جلسات الليل.",
                tint: AamalTheme.gold,
                systemImage: "chart.bar.fill"
            )

            let sessions = store.quranRevisionPlan.qiyamSessions
            let totalAyat = sessions.reduce(0) { $0 + $1.ayatCount }
            let streak = store.quranRevisionPlan.qiyamStreak

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                QuranMetricPill(title: "إجمالي الآيات", value: "\(totalAyat)", accent: AamalTheme.emerald)
                QuranMetricPill(title: "السلسلة الحالية", value: "\(streak) يوم", accent: AamalTheme.gold)
                QuranMetricPill(title: "عدد الجلسات", value: "\(sessions.count)", accent: AamalTheme.mint)
                QuranMetricPill(title: "متوسط الجلسة", value: averageSessionText, accent: AamalTheme.ink.opacity(0.8))
            }
        }
        .aamalCardSolid()
    }

    private var averageSessionText: String {
        let sessions = store.quranRevisionPlan.qiyamSessions
        guard !sessions.isEmpty else { return "0" }
        let avg = sessions.reduce(0) { $0 + $1.ayatCount } / sessions.count
        return "\(avg) آية"
    }
}

private struct QiyamSettingsSheet: View {
    @ObservedObject var store: TaskStore
    @Binding var isPresented: Bool
    @State private var qiyamEnabled: Bool

    init(store: TaskStore, isPresented: Binding<Bool>) {
        self.store = store
        self._isPresented = isPresented
        self._qiyamEnabled = State(initialValue: store.quranRevisionPlan.qiyamEnabled)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("دمج القيام")) {
                    Toggle("تفعيل دمج قيام الليل", isOn: $qiyamEnabled)
                    Text("عند التفعيل، يُحتسب القيام كجلسة مراجعة رحيمة تخفف من عبء المراجعة اليومي.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("إعدادات القيام")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        store.setQiyamEnabled(qiyamEnabled)
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
