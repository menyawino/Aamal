import SwiftUI
import CoreLocation

struct PrayerTimesTabView: View {
    @ObservedObject var store: TaskStore
    @StateObject private var locationManager = LocationManager()
    @StateObject private var prayerViewModel: PrayerTimesViewModel
    @State private var showDebug = false

    init(store: TaskStore) {
        self.store = store
        _prayerViewModel = StateObject(wrappedValue: PrayerTimesViewModel(store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    PrayerTimesWidgetCard(timings: prayerViewModel.timings)

                    PrayerTimesListCard(locationManager: locationManager, viewModel: prayerViewModel)

                    DebugPrayerTimesCard(showDebug: $showDebug, locationManager: locationManager, viewModel: prayerViewModel)
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("أوقات الصلاة")
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .onChange(of: locationManager.location) { _, location in
            guard let location else { return }
            prayerViewModel.refresh(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        }
    }
}

private struct PrayerTimesWidgetCard: View {
    let timings: PrayerTimings?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("المؤقت", systemImage: "timer")
                    .font(.headline)
                    .foregroundColor(AamalTheme.emerald)
                Spacer()
                Text(formattedNow)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let timings {
                ForEach(timings.slots()) { slot in
                    PrayerCountdownRow(slot: slot)
                }
            } else {
                Text("جاري تحميل أوقات الصلاة...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .aamalCardSolid()
    }

    private var formattedNow: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
}

private struct PrayerCountdownRow: View {
    let slot: PrayerSlot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(slot.arabicName)
                    .font(.subheadline)
                Text(statusText)
                    .font(.caption)
                    .foregroundColor(statusColor)
            }
            Spacer()
            Text(slot.date, style: .time)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 4)
        )
    }

    private var statusText: String {
        let minutes = Int(Date().distance(to: slot.date) / 60)
        if minutes >= 0 {
            return "باقي \(minutes) دقيقة"
        }
        return "مرّ \(abs(minutes)) دقيقة"
    }

    private var statusColor: Color {
        let minutes = Int(Date().distance(to: slot.date) / 60)
        return minutes >= 0 ? AamalTheme.emerald : .secondary
    }
}

private struct PrayerTimesListCard: View {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: PrayerTimesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("الأوقات بالتفصيل", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundColor(AamalTheme.emerald)
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                        .tint(AamalTheme.gold)
                }
            }

            if let placeName = locationManager.placeName {
                Text(placeName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("جارٍ تحديد الموقع...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if let timings = viewModel.timings {
                ForEach(timings.slots()) { slot in
                    HStack {
                        Text(slot.arabicName)
                            .font(.subheadline)
                        Spacer()
                        Text(slot.date, style: .time)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                Text(locationManager.errorMessage ?? viewModel.statusMessage ?? "فعّل الموقع لجلب أوقات الصلاة")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                Text("أو أدخل المدينة يدويًا")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    TextField("المدينة", text: $viewModel.manualCity)
                        .textFieldStyle(.roundedBorder)
                    TextField("الدولة", text: $viewModel.manualCountry)
                        .textFieldStyle(.roundedBorder)
                }

                Button(action: {
                    viewModel.refresh(city: viewModel.manualCity, country: viewModel.manualCountry)
                }) {
                    Text("جلب الأوقات بالمدينة")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(AamalTheme.gold)
            }

            Button(action: {
                locationManager.requestLocation()
            }) {
                Text("تحديث أوقات الصلاة")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(AamalTheme.emerald)

            Text("سيتم تذكيرك بالوضوء والمهام المرتبطة بالصلاة في أوقاتها")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .aamalCardSolid()
    }
}

private struct DebugPrayerTimesCard: View {
    @Binding var showDebug: Bool
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: PrayerTimesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("تشخيص أوقات الصلاة", isOn: $showDebug)
                .font(.headline)

            if showDebug {
                VStack(alignment: .leading, spacing: 6) {
                    Text("الحالة: \(locationStatusText)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let location = locationManager.location {
                        Text("الإحداثيات: \(String(format: "%.4f", location.coordinate.latitude)), \(String(format: "%.4f", location.coordinate.longitude))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let placeName = locationManager.placeName {
                        Text("الموقع المقروء: \(placeName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let error = locationManager.errorMessage {
                        Text("خطأ الموقع: \(error)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if !viewModel.debugInfo.isEmpty {
                        Text("التحديث: \(viewModel.debugInfo)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let status = viewModel.statusMessage {
                        Text("رسالة: \(status)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .aamalCardSolid()
    }

    private var locationStatusText: String {
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            return "مصرح دائمًا"
        case .authorizedWhenInUse:
            return "مصرح أثناء الاستخدام"
        case .denied:
            return "مرفوض"
        case .restricted:
            return "مقيّد"
        case .notDetermined:
            return "غير محدد"
        @unknown default:
            return "غير معروف"
        }
    }
}
