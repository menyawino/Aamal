import Foundation
import Combine

struct PrayerTimings: Equatable {
    let fajr: Date
    let dhuhr: Date
    let asr: Date
    let maghrib: Date
    let isha: Date

    func slots() -> [PrayerSlot] {
        [
            PrayerSlot(apiKey: "Fajr", arabicName: "الصبح", date: fajr),
            PrayerSlot(apiKey: "Dhuhr", arabicName: "الظهر", date: dhuhr),
            PrayerSlot(apiKey: "Asr", arabicName: "العصر", date: asr),
            PrayerSlot(apiKey: "Maghrib", arabicName: "المغرب", date: maghrib),
            PrayerSlot(apiKey: "Isha", arabicName: "العشاء", date: isha)
        ]
    }
}

struct PrayerSlot: Identifiable, Equatable {
    let id = UUID()
    let apiKey: String
    let arabicName: String
    let date: Date
}

final class PrayerTimesService {
    private struct Response: Decodable {
        struct DataBlock: Decodable {
            struct Timings: Decodable {
                let Fajr: String
                let Dhuhr: String
                let Asr: String
                let Maghrib: String
                let Isha: String
            }

            struct Meta: Decodable {
                let timezone: String
            }

            let timings: Timings
            let meta: Meta
        }

        let data: DataBlock
    }

    func fetchTimings(latitude: Double, longitude: Double, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        let urlString = "https://api.aladhan.com/v1/timings?latitude=\(latitude)&longitude=\(longitude)&method=2"
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    let timeZone = TimeZone(identifier: response.data.meta.timezone) ?? .current
                    let calendar = Calendar.current

                    let fajr = try self.timeFrom(response.data.timings.Fajr, timeZone: timeZone, calendar: calendar)
                    let dhuhr = try self.timeFrom(response.data.timings.Dhuhr, timeZone: timeZone, calendar: calendar)
                    let asr = try self.timeFrom(response.data.timings.Asr, timeZone: timeZone, calendar: calendar)
                    let maghrib = try self.timeFrom(response.data.timings.Maghrib, timeZone: timeZone, calendar: calendar)
                    let isha = try self.timeFrom(response.data.timings.Isha, timeZone: timeZone, calendar: calendar)

                    completion(.success(PrayerTimings(fajr: fajr, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha)))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    func fetchTimings(city: String, country: String, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        guard let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let encodedCountry = country.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        let urlString = "https://api.aladhan.com/v1/timingsByCity?city=\(encodedCity)&country=\(encodedCountry)&method=2"
        guard let url = URL(string: urlString) else {
            completion(.failure(URLError(.badURL)))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    let timeZone = TimeZone(identifier: response.data.meta.timezone) ?? .current
                    let calendar = Calendar.current

                    let fajr = try self.timeFrom(response.data.timings.Fajr, timeZone: timeZone, calendar: calendar)
                    let dhuhr = try self.timeFrom(response.data.timings.Dhuhr, timeZone: timeZone, calendar: calendar)
                    let asr = try self.timeFrom(response.data.timings.Asr, timeZone: timeZone, calendar: calendar)
                    let maghrib = try self.timeFrom(response.data.timings.Maghrib, timeZone: timeZone, calendar: calendar)
                    let isha = try self.timeFrom(response.data.timings.Isha, timeZone: timeZone, calendar: calendar)

                    completion(.success(PrayerTimings(fajr: fajr, dhuhr: dhuhr, asr: asr, maghrib: maghrib, isha: isha)))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func timeFrom(_ timeString: String, timeZone: TimeZone, calendar: Calendar) throws -> Date {
        let cleaned = timeString.components(separatedBy: " ").first ?? timeString
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = timeZone

        guard let parsedTime = formatter.date(from: cleaned) else {
            throw URLError(.cannotParseResponse)
        }

        var calendar = calendar
        calendar.timeZone = timeZone

        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        let timeComponents = calendar.dateComponents([.hour, .minute], from: parsedTime)
        components.hour = timeComponents.hour
        components.minute = timeComponents.minute
        components.second = 0

        guard let date = calendar.date(from: components) else {
            throw URLError(.cannotParseResponse)
        }

        return date
    }
}

@MainActor
final class PrayerTimesViewModel: ObservableObject {
    @Published var timings: PrayerTimings?
    @Published var statusMessage: String?
    @Published var isLoading: Bool = false
    @Published var manualCity: String = ""
    @Published var manualCountry: String = ""
    @Published var debugInfo: String = ""

    private let service = PrayerTimesService()
    private let store: TaskStore

    init(store: TaskStore) {
        self.store = store
    }

    func refresh(latitude: Double, longitude: Double) {
        isLoading = true
        statusMessage = nil
        debugInfo = "جاري الجلب حسب الإحداثيات: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"

        service.fetchTimings(latitude: latitude, longitude: longitude) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let timings):
                    self.timings = timings
                    self.store.schedulePrayerNotifications(timings: timings)
                    self.isLoading = false
                    self.debugInfo = "تم التحديث بنجاح عبر الإحداثيات."
                case .failure:
                    self.statusMessage = "تعذر جلب أوقات الصلاة. حاول لاحقًا."
                    self.isLoading = false
                    self.debugInfo = "فشل الجلب عبر الإحداثيات."
                }
            }
        }
    }

    func refresh(city: String, country: String) {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "أدخل المدينة والدولة أولاً."
            return
        }

        isLoading = true
        statusMessage = nil
        debugInfo = "جاري الجلب حسب المدينة: \(city)، \(country)"

        service.fetchTimings(city: city, country: country) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let timings):
                    self.timings = timings
                    self.store.schedulePrayerNotifications(timings: timings)
                    self.isLoading = false
                    self.debugInfo = "تم التحديث بنجاح عبر المدينة."
                case .failure:
                    self.statusMessage = "تعذر جلب أوقات الصلاة لهذه المدينة."
                    self.isLoading = false
                    self.debugInfo = "فشل الجلب عبر المدينة."
                }
            }
        }
    }
}
