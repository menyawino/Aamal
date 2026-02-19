import SwiftUI
import Charts

struct RamadanView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedDate = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    RamadanSummaryCard(store: store)
                    RamadanProgressChartCard(store: store)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("متابعة يوم محدد")
                            .font(.headline)
                        Text("اختر يوماً سابقاً لمراجعة الإنجاز والعادات")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("اختر اليوم", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                    }
                    .aamalCard()

                    RamadanHabitsChecklist(store: store, date: selectedDate)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("رمضان")
        }
    }
}

private struct RamadanProgressChartCard: View {
    @ObservedObject var store: TaskStore

    private var series: [RamadanProgressPoint] {
        store.ramadanSeries(maxDays: 30)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("منحنى رمضان")
                .font(.headline)
            Text("متوسط الإنجاز اليومي خلال الشهر")
                .font(.caption)
                .foregroundColor(.secondary)

            if series.isEmpty {
                Text("ابدأ بتسجيل إنجازات رمضان لعرض المخطط")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Chart(series) { point in
                    BarMark(
                        x: .value("اليوم", point.date),
                        y: .value("الإنجاز", point.value * 100)
                    )
                    .foregroundStyle(AamalTheme.gold.gradient)
                    .cornerRadius(4)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.day())
                    }
                }
                .frame(height: 180)
            }
        }
        .aamalCard()
    }
}

private struct RamadanSummaryCard: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.isRamadanNow ? "رمضان كريم" : "متابعة رمضان")
                        .font(.headline)
                    Text("اليوم \(store.ramadanDayNumber) • متبقي تقريبيًا \(store.ramadanRemainingDaysEstimate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "moon.stars.fill")
                    .foregroundColor(AamalTheme.gold)
                    .font(.title2)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("إنجاز اليوم: \(Int(store.ramadanTodayProgress * 100))٪")
                    .font(.subheadline)
                ProgressView(value: store.ramadanTodayProgress)
                    .tint(AamalTheme.emerald)
            }

            HStack {
                Text("سلسلة الصيام")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(store.ramadanFastingStreak) يوم")
                    .font(.subheadline)
                    .foregroundColor(AamalTheme.ink)
            }
        }
        .aamalCardSolid()
    }
}

private struct RamadanHabitsChecklist: View {
    @ObservedObject var store: TaskStore
    let date: Date

    private var suhoorHabits: [RamadanHabit] {
        RamadanHabit.allCases.filter { $0.section == .suhoor }
    }

    private var iftarHabits: [RamadanHabit] {
        RamadanHabit.allCases.filter { $0.section == .iftar }
    }

    private var generalHabits: [RamadanHabit] {
        RamadanHabit.allCases.filter { $0.section == .general }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("قائمة إنجاز رمضان")
                    .font(.headline)
                Text("سجّل ما تم لكل فترة ثم راجع نسبة التقدم")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if !store.isRamadanDay(date) {
                Text("اليوم المحدد خارج شهر رمضان (هجري). يمكنك متابعة سجل أيام رمضان فقط.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            RamadanHabitSectionList(
                title: RamadanHabitSection.suhoor.title,
                habits: suhoorHabits,
                store: store,
                date: date
            )

            RamadanHabitSectionList(
                title: RamadanHabitSection.iftar.title,
                habits: iftarHabits,
                store: store,
                date: date
            )

            RamadanHabitSectionList(
                title: RamadanHabitSection.general.title,
                habits: generalHabits,
                store: store,
                date: date
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("نسبة إنجاز اليوم المحدد: \(Int(store.ramadanProgress(on: date) * 100))٪")
                    .font(.caption)
                    .foregroundColor(.secondary)
                ProgressView(value: store.ramadanProgress(on: date))
                    .tint(AamalTheme.gold)
            }
            .padding(.top, 6)
        }
        .aamalCard()
    }
}

private struct RamadanHabitSectionList: View {
    let title: String
    let habits: [RamadanHabit]
    @ObservedObject var store: TaskStore
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 2)

            ForEach(habits, id: \.rawValue) { habit in
                RamadanHabitRow(
                    title: habit.title,
                    isDone: store.isRamadanHabitCompleted(habit, on: date),
                    onToggle: {
                        store.toggleRamadanHabit(habit, on: date)
                    }
                )
            }
        }
    }
}

private struct RamadanHabitRow: View {
    let title: String
    let isDone: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                Text(isDone ? "مكتمل" : "غير مكتمل")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onToggle) {
                Text(isDone ? "إلغاء" : "تم")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(isDone ? .gray : AamalTheme.emerald)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
