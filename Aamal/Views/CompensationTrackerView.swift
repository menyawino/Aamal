import SwiftUI

struct CompensationTrackerView: View {
    @ObservedObject var store: TaskStore
    @State private var prayerTargets: [PrayerCompensationType: Int]
    @State private var fastingDays: Int
    @State private var selectedPrayer: PrayerCompensationType = .fajr
    @State private var prayerLogCount: Int = 1
    @State private var fastingLogCount: Int = 1
    @State private var feedbackMessage: String = ""
    @State private var showSettingsSheet = false

    init(store: TaskStore) {
        self.store = store
        _prayerTargets = State(initialValue: Dictionary(uniqueKeysWithValues: PrayerCompensationType.allCases.map {
            ($0, store.prayerDebtCount(for: $0))
        }))
        _fastingDays = State(initialValue: store.compensationProgress.fastingDebtDays)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    CompensationHeroCard(store: store)

                    if !feedbackMessage.isEmpty {
                        Text(feedbackMessage)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(AamalTheme.emerald)
                            .aamalCard()
                    }

                    CompensationSettingsLauncherCard(
                        store: store,
                        openSettingsAction: { showSettingsSheet = true }
                    )

                    CompensationQuickLogCard(
                        store: store,
                        selectedPrayer: $selectedPrayer,
                        prayerLogCount: $prayerLogCount,
                        fastingLogCount: $fastingLogCount,
                        prayerAction: logPrayerCompensation,
                        fastingAction: logFastingCompensation
                    )

                    CompensationRemainingCard(store: store)

                    CompensationQuestCard(store: store)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettingsSheet = true }) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("إعدادات القضاء")
                }
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("القضاء")
        }
        .onAppear(perform: syncDraft)
        .sheet(isPresented: $showSettingsSheet) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        CompensationTargetEditorCard(
                            prayerTargets: $prayerTargets,
                            fastingDays: $fastingDays,
                            saveAction: saveTargets
                        )
                    }
                    .padding()
                }
                .background(AamalTheme.backgroundGradient.ignoresSafeArea())
                .navigationTitle("إعدادات القضاء")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("إغلاق") {
                            syncDraft()
                            showSettingsSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func syncDraft() {
        prayerTargets = Dictionary(uniqueKeysWithValues: PrayerCompensationType.allCases.map {
            ($0, store.prayerDebtCount(for: $0))
        })
        fastingDays = store.compensationProgress.fastingDebtDays
        prayerLogCount = max(1, min(prayerLogCount, max(1, store.remainingPrayerDebt(for: selectedPrayer))))
        fastingLogCount = max(1, min(fastingLogCount, max(1, store.remainingFastingDebtDays)))
    }

    private func saveTargets() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            store.updateCompensationTargets(prayerCounts: prayerTargets, fastingDays: fastingDays)
            feedbackMessage = "تم تحديث رصيد القضاء والمتابعة مستمرة."
        }
        syncDraft()
        showSettingsSheet = false
    }

    private func logPrayerCompensation() {
        let logged = store.logCompensatedPrayer(selectedPrayer, count: prayerLogCount)
        guard logged > 0 else {
            feedbackMessage = "لا يوجد رصيد متبق لهذه الصلاة."
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            feedbackMessage = "تم تسجيل \(logged) من قضاء \(selectedPrayer.arabicName)."
        }
        prayerLogCount = max(1, min(prayerLogCount, max(1, store.remainingPrayerDebt(for: selectedPrayer))))
    }

    private func logFastingCompensation() {
        let logged = store.logCompensatedFastingDays(fastingLogCount)
        guard logged > 0 else {
            feedbackMessage = "لا توجد أيام صيام متبقية في الرصيد."
            return
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            feedbackMessage = "تم تسجيل \(logged) يوم صيام قضاء."
        }
        fastingLogCount = max(1, min(fastingLogCount, max(1, store.remainingFastingDebtDays)))
    }
}

private struct CompensationHeroCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.compensationRankTitle)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("أنجزت \(store.totalCompensatedDebtUnits) من أصل \(store.totalCompensationDebtUnits)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("سلسلة القضاء")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(store.compensationProgress.streak) أيام")
                        .font(.headline)
                        .foregroundColor(AamalTheme.emerald)
                }
            }

            ProgressView(value: store.compensationCompletionRate)
                .tint(AamalTheme.gold)

            HStack {
                CompensationMetricPill(title: "الصلوات المتبقية", value: "\(store.remainingPrayerDebtCount)")
                CompensationMetricPill(title: "أيام الصيام", value: "\(store.remainingFastingDebtDays)")
                CompensationMetricPill(title: "نسبة الإنجاز", value: "\(Int(store.compensationCompletionRate * 100))٪")
            }
        }
        .aamalCard()
    }
}

private struct CompensationMetricPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(AamalTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(AamalTheme.emerald.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct CompensationSettingsLauncherCard: View {
    @ObservedObject var store: TaskStore
    let openSettingsAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("إعدادات الرصيد")
                        .font(.headline)
                    Text(summaryText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: openSettingsAction) {
                    Label("تعديل", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(.bordered)
                .tint(AamalTheme.gold)
            }

            HStack {
                CompensationMetricPill(title: "الرصيد الكلي", value: "\(store.totalCompensationDebtUnits)")
                CompensationMetricPill(title: "المتبقي", value: "\(store.totalCompensationDebtUnits - store.totalCompensatedDebtUnits)")
                CompensationMetricPill(title: "سلسلة القضاء", value: "\(store.compensationProgress.streak)")
            }
        }
        .aamalCardSolid()
    }

    private var summaryText: String {
        if store.totalCompensationDebtUnits == 0 {
            return "أدخل رصيد الصلوات وأيام الصيام مرة واحدة، ثم عدله لاحقًا من الإعدادات."
        }
        return "تعديل رصيد الصلوات وأيام الصيام أصبح من الإعدادات حتى تبقى الصفحة أخف."
    }
}

private struct CompensationTargetEditorCard: View {
    @Binding var prayerTargets: [PrayerCompensationType: Int]
    @Binding var fastingDays: Int
    let saveAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("رصيد ما فاتك")
                .font(.headline)

            Text("عدّل العدد متى احتجت، ثم احفظ ليعود ملخص الصفحة بشكل مضغوط.")
                .font(.caption)
                .foregroundColor(.secondary)

            ForEach(PrayerCompensationType.allCases) { prayer in
                NumericStepperRow(
                    title: prayer.arabicName,
                    systemImage: prayer.systemImage,
                    value: binding(for: prayer),
                    range: 0...5000
                )
            }

            NumericStepperRow(
                title: "أيام الصيام",
                systemImage: "calendar",
                value: $fastingDays,
                range: 0...5000
            )

            Button(action: saveAction) {
                Text("حفظ رصيد القضاء")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.emerald)
        }
        .aamalCard()
    }

    private func binding(for prayer: PrayerCompensationType) -> Binding<Int> {
        Binding(
            get: { prayerTargets[prayer, default: 0] },
            set: { prayerTargets[prayer] = max(0, $0) }
        )
    }
}

private struct CompensationQuickLogCard: View {
    @ObservedObject var store: TaskStore
    @Binding var selectedPrayer: PrayerCompensationType
    @Binding var prayerLogCount: Int
    @Binding var fastingLogCount: Int
    let prayerAction: () -> Void
    let fastingAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("تسجيل القضاء المنجز")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                Picker("الصلاة", selection: $selectedPrayer) {
                    ForEach(PrayerCompensationType.allCases) { prayer in
                        Text(prayer.arabicName).tag(prayer)
                    }
                }
                .pickerStyle(.segmented)

                NumericStepperRow(
                    title: "عدد الصلوات المقضية",
                    systemImage: "checkmark.circle",
                    value: $prayerLogCount,
                    range: 1...max(1, store.remainingPrayerDebt(for: selectedPrayer))
                )

                Button(action: prayerAction) {
                    Text("تسجيل قضاء الصلاة")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.remainingPrayerDebt(for: selectedPrayer) == 0)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                NumericStepperRow(
                    title: "عدد الأيام المقضية",
                    systemImage: "calendar.badge.checkmark",
                    value: $fastingLogCount,
                    range: 1...max(1, store.remainingFastingDebtDays)
                )

                Button(action: fastingAction) {
                    Text("تسجيل قضاء الصيام")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(store.remainingFastingDebtDays == 0)
            }
        }
        .aamalCard()
    }
}

private struct NumericStepperRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(title, systemImage: systemImage)
                Spacer()
                TextField("0", value: clampedBinding, format: .number)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 88)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(AamalTheme.emerald.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Stepper(value: clampedBinding, in: range) {
                Text("القيمة الحالية: \(value)")
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

private struct CompensationRemainingCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("خريطة المتبقي")
                .font(.headline)

            ForEach(PrayerCompensationType.allCases) { prayer in
                HStack {
                    Label(prayer.arabicName, systemImage: prayer.systemImage)
                    Spacer()
                    Text("\(store.compensatedPrayerCount(for: prayer))/\(store.prayerDebtCount(for: prayer))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("متبقي \(store.remainingPrayerDebt(for: prayer))")
                        .font(.subheadline)
                        .foregroundColor(store.remainingPrayerDebt(for: prayer) == 0 ? AamalTheme.emerald : AamalTheme.ink)
                }
                ProgressView(
                    value: Double(store.compensatedPrayerCount(for: prayer)),
                    total: Double(max(1, store.prayerDebtCount(for: prayer)))
                )
                .tint(AamalTheme.emerald)
            }

            HStack {
                Label("الصيام", systemImage: "calendar.badge.clock")
                Spacer()
                Text("\(store.compensationProgress.compensatedFastingDays)/\(store.compensationProgress.fastingDebtDays)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("متبقي \(store.remainingFastingDebtDays)")
                    .font(.subheadline)
                    .foregroundColor(store.remainingFastingDebtDays == 0 ? AamalTheme.emerald : AamalTheme.ink)
            }
            ProgressView(
                value: Double(store.compensationProgress.compensatedFastingDays),
                total: Double(max(1, store.compensationProgress.fastingDebtDays))
            )
            .tint(AamalTheme.gold)
        }
        .aamalCard()
    }
}

private struct CompensationQuestCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مهمة اليوم")
                .font(.headline)
            Text(store.compensationSuggestedFocus)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack {
                Label("كل صلاة قضاء تمنحك 3 نقاط", systemImage: "sparkles")
                    .font(.caption)
                Spacer()
                Label("كل يوم صيام يمنحك 12 نقطة", systemImage: "bolt.fill")
                    .font(.caption)
            }
            .foregroundColor(AamalTheme.gold)
        }
        .aamalCardSolid()
    }
}