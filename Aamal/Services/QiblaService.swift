import Foundation
import CoreLocation

enum QiblaService {
    private static let makkahLatitude = 21.4225
    private static let makkahLongitude = 39.8262

    static func bearingFrom(latitude: Double, longitude: Double) -> Double {
        let userLat = latitude * .pi / 180
        let userLon = longitude * .pi / 180
        let makkahLat = makkahLatitude * .pi / 180
        let makkahLon = makkahLongitude * .pi / 180

        let deltaLon = makkahLon - userLon
        let y = sin(deltaLon) * cos(makkahLat)
        let x = cos(userLat) * sin(makkahLat) - sin(userLat) * cos(makkahLat) * cos(deltaLon)
        let radians = atan2(y, x)
        let degrees = radians * 180 / .pi
        let normalized = (degrees + 360).truncatingRemainder(dividingBy: 360)
        return normalized
    }

    static func cardinalDirection(for bearing: Double) -> String {
        switch bearing {
        case 22.5..<67.5: return "شمال شرقي"
        case 67.5..<112.5: return "شرق"
        case 112.5..<157.5: return "جنوب شرقي"
        case 157.5..<202.5: return "جنوب"
        case 202.5..<247.5: return "جنوب غربي"
        case 247.5..<292.5: return "غرب"
        case 292.5..<337.5: return "شمال غربي"
        default: return "شمال"
        }
    }
}
