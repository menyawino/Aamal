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
    enum PrayerTimesError: LocalizedError {
        case invalidResponse
        case invalidStatus(code: Int, message: String)
        case invalidPayload(message: String)

        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "استجابة غير صالحة من الخادم."
            case .invalidStatus(let code, let message):
                return "فشل الطلب (\(code)): \(message)"
            case .invalidPayload(let message):
                return "بيانات غير صالحة: \(message)"
            }
        }
    }

    private struct Response: Decodable {
        let code: Int?
        let status: String?
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

        let data: DataBlock?
    }

    func fetchTimings(latitude: Double, longitude: Double, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        fetchTimings(latitude: latitude, longitude: longitude, method: 2, completion: completion)
    }

    func fetchTimingsWithFallback(latitude: Double, longitude: Double, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        let methods = [2, 3, 4, 5]
        fetchTimingsWithMethods(latitude: latitude, longitude: longitude, methods: methods, index: 0, completion: completion)
    }

    private func fetchTimings(latitude: Double, longitude: Double, method: Int, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        var components = URLComponents(string: "https://api.aladhan.com/v1/timings")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.6f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.6f", longitude)),
            URLQueryItem(name: "method", value: "\(method)")
        ]
        guard let url = components?.url else {
            completion(.failure(URLError(.badURL)))
            return
        }
        print("[PrayerTimesService DEBUG] fetchTimings(latitude:longitude:) URL: \(url.absoluteString) with latitude: \(latitude), longitude: \(longitude), method: \(method)")
        performRequest(url: url, completion: completion)
    }

    func fetchTimings(city: String, country: String, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        fetchTimings(city: city, country: country, method: 2, completion: completion)
    }

    func fetchTimingsByCityWithFallback(city: String, country: String, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        let methods = [2, 3, 4, 5]
        fetchTimingsByCityWithMethods(city: city, country: country, methods: methods, index: 0, completion: completion)
    }

    private func fetchTimings(city: String, country: String, method: Int, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        var components = URLComponents(string: "https://api.aladhan.com/v1/timingsByCity")
        components?.queryItems = [
            URLQueryItem(name: "city", value: city),
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "method", value: "\(method)")
        ]
        guard let url = components?.url else {
            completion(.failure(URLError(.badURL)))
            return
        }
        print("[PrayerTimesService DEBUG] fetchTimings(city:country:) URL: \(url.absoluteString) with city: \(city), country: \(country), method: \(method)")
        performRequest(url: url, completion: completion)
    }

    private func fetchTimingsWithMethods(latitude: Double, longitude: Double, methods: [Int], index: Int, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        guard index < methods.count else {
            completion(.failure(PrayerTimesError.invalidPayload(message: "تعذر جلب أوقات الصلاة بعد عدة محاولات.")))
            return
        }

        let method = methods[index]
        fetchTimings(latitude: latitude, longitude: longitude, method: method) { result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                self.fetchTimingsWithMethods(latitude: latitude, longitude: longitude, methods: methods, index: index + 1, completion: completion)
            }
        }
    }

    private func fetchTimingsByCityWithMethods(city: String, country: String, methods: [Int], index: Int, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        guard index < methods.count else {
            completion(.failure(PrayerTimesError.invalidPayload(message: "تعذر جلب أوقات الصلاة حسب المدينة بعد عدة محاولات.")))
            return
        }

        let method = methods[index]
        fetchTimings(city: city, country: country, method: method) { result in
            switch result {
            case .success:
                completion(result)
            case .failure:
                self.fetchTimingsByCityWithMethods(city: city, country: country, methods: methods, index: index + 1, completion: completion)
            }
        }
    }

    private func performRequest(url: URL, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        performRequest(url: url, attempt: 0, completion: completion)
    }

    private func performRequest(url: URL, attempt: Int, completion: @escaping (Result<PrayerTimings, Error>) -> Void) {
        print("[PrayerTimesService DEBUG] performRequest URL: \(url.absoluteString), attempt: \(attempt)")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15

        if attempt == 0 {
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
            request.setValue("AmaalApp/1.0", forHTTPHeaderField: "User-Agent")
        } else {
            request.setValue("*/*", forHTTPHeaderField: "Accept")
        }

        let session: URLSession
        if attempt == 0 {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.waitsForConnectivity = true
            session = URLSession(configuration: configuration)
        } else {
            session = URLSession.shared
        }

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[PrayerTimesService DEBUG] URLSession error: \(error)")
                if let httpResponse = response as? HTTPURLResponse {
                    print("[PrayerTimesService DEBUG] HTTP Response: \(httpResponse.statusCode)")
                    print("[PrayerTimesService DEBUG] Headers: \(httpResponse.allHeaderFields)")
                }

                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain,
                   nsError.code == NSURLErrorCannotParseResponse,
                   attempt == 0 {
                    print("[PrayerTimesService DEBUG] retrying with identity encoding")
                    self.performRequest(url: url, attempt: 1, completion: completion)
                    return
                }

                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(URLError(.badServerResponse)))
                return
            }

            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                let body = String(data: data, encoding: .utf8) ?? ""
                completion(.failure(PrayerTimesError.invalidStatus(code: http.statusCode, message: body)))
                return
            }

            DispatchQueue.main.async {
                do {
                    let response = try JSONDecoder().decode(Response.self, from: data)
                    if let code = response.code, code != 200 {
                        completion(.failure(PrayerTimesError.invalidStatus(code: code, message: response.status ?? "")))
                        return
                    }
                    guard let dataBlock = response.data else {
                        completion(.failure(PrayerTimesError.invalidPayload(message: response.status ?? "")))
                        return
                    }

                    let timeZone = TimeZone(identifier: dataBlock.meta.timezone) ?? .current
                    let calendar = Calendar.current

                    let fajr = try self.timeFrom(dataBlock.timings.Fajr, timeZone: timeZone, calendar: calendar)
                    let dhuhr = try self.timeFrom(dataBlock.timings.Dhuhr, timeZone: timeZone, calendar: calendar)
                    let asr = try self.timeFrom(dataBlock.timings.Asr, timeZone: timeZone, calendar: calendar)
                    let maghrib = try self.timeFrom(dataBlock.timings.Maghrib, timeZone: timeZone, calendar: calendar)
                    let isha = try self.timeFrom(dataBlock.timings.Isha, timeZone: timeZone, calendar: calendar)

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
    private var lastRequestSignature: String?
    private var lastRequestTime: Date?
    private let minimumRefreshInterval: TimeInterval = 12

    init(store: TaskStore) {
        self.store = store
    }

    private func shouldSkipRequest(signature: String, force: Bool) -> Bool {
        if force { return false }
        if let lastSignature = lastRequestSignature,
           let lastTime = lastRequestTime,
           lastSignature == signature,
           Date().timeIntervalSince(lastTime) < minimumRefreshInterval {
            return true
        }
        return false
    }

    private func applySuccessfulFetch(_ timings: PrayerTimings, source: String) {
        self.timings = timings
        self.store.schedulePrayerNotifications(timings: timings)
        self.statusMessage = nil
        self.isLoading = false
        self.debugInfo = source
    }

    func refresh(latitude: Double, longitude: Double, fallbackCity: String? = nil, fallbackCountry: String? = nil, force: Bool = false) {
        let signature = "coord:\(String(format: "%.4f", latitude)),\(String(format: "%.4f", longitude))"
        if shouldSkipRequest(signature: signature, force: force) {
            debugInfo = "تم تجاهل التحديث لتقليل التكرار."
            return
        }

        lastRequestSignature = signature
        lastRequestTime = Date()
        isLoading = true
        statusMessage = nil
        debugInfo = "جاري الجلب حسب الإحداثيات: \(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude))"

        service.fetchTimingsWithFallback(latitude: latitude, longitude: longitude) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let timings):
                    self.applySuccessfulFetch(timings, source: "تم التحديث بنجاح عبر الإحداثيات.")
                case .failure:
                    let city = (fallbackCity?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty ? "Cairo" : fallbackCity!.trimmingCharacters(in: .whitespacesAndNewlines)
                    let country = (fallbackCountry?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty ? "Egypt" : fallbackCountry!.trimmingCharacters(in: .whitespacesAndNewlines)

                    self.debugInfo = "فشل الإحداثيات، جارٍ المحاولة عبر المدينة: \(city)، \(country) (افتراضي)"

                    self.service.fetchTimingsByCityWithFallback(city: city, country: country) { [weak self] cityResult in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            switch cityResult {
                            case .success(let timings):
                                self.applySuccessfulFetch(timings, source: "تم التحديث عبر المدينة بعد فشل الإحداثيات.")
                            case .failure(let cityError):
                                self.statusMessage = "تعذر جلب أوقات الصلاة عبر الموقع والمدينة."
                                self.isLoading = false
                                let nsError = cityError as NSError
                                self.debugInfo = "فشل الجلب عبر المدينة أيضًا: \(nsError.domain) (\(nsError.code)) - \(nsError.localizedDescription)"
                            }
                        }
                    }
                }
            }
        }
    }

    func refresh(city: String, country: String, force: Bool = false) {
        guard !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusMessage = "أدخل المدينة والدولة أولاً."
            return
        }

        let signature = "city:\(city.lowercased())|country:\(country.lowercased())"
        if shouldSkipRequest(signature: signature, force: force) {
            debugInfo = "تم تجاهل التحديث لتقليل التكرار."
            return
        }

        lastRequestSignature = signature
        lastRequestTime = Date()

        isLoading = true
        statusMessage = nil
        debugInfo = "جاري الجلب حسب المدينة: \(city)، \(country)"

        service.fetchTimingsByCityWithFallback(city: city, country: country) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let timings):
                    self.applySuccessfulFetch(timings, source: "تم التحديث بنجاح عبر المدينة.")
                case .failure:
                    self.statusMessage = "تعذر جلب أوقات الصلاة لهذه المدينة."
                    self.isLoading = false
                    self.debugInfo = "فشل الجلب عبر المدينة"
                }
            }
        }
    }
}
