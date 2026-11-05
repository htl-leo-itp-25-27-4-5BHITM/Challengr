import Foundation
import CoreLocation

/// Himmel über der Karte: aus dem echten Sonnenstand am Standort.
/// Rein dekorativ – auf Spielregeln, Trophäen oder Punkte hat die Tageszeit keinen Einfluss.
struct SkyState: Equatable {
    /// Sonnenhöhe über dem Horizont in Grad (negativ = unter dem Horizont)
    let elevation: Double
    /// Sonne steigt gerade (Morgen) oder sinkt (Abend)
    let rising: Bool

    /// Karte dunkel, sobald die Sonne knapp unter dem Horizont ist.
    var isDark: Bool { elevation < -1 }

    /// Stärke des Dämmerungs-Schimmers (0…1): am stärksten kurz vor/nach Sonnenauf-/-untergang.
    var twilight: Double {
        guard elevation > -8, elevation < 10 else { return 0 }
        return max(0, 1 - abs(elevation - 1) / 9)
    }

    /// Wie sehr es Nacht ist (0…1): Sterne blenden zwischen 0° und −8° ein.
    var night: Double {
        min(1, max(0, -elevation / 8))
    }
}

enum SkyCycle {
    /// Sonnenhöhe (Grad) nach der NOAA-Näherung – auf etwa ein Zehntelgrad genau, reicht für Tag/Nacht.
    static func sunElevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        let rad = Double.pi / 180
        let n = date.timeIntervalSince1970 / 86_400 + 2_440_587.5 - 2_451_545.0   // Tage seit J2000
        let meanLongitude = (280.460 + 0.985_647_4 * n).truncatingRemainder(dividingBy: 360)
        let meanAnomaly = (357.528 + 0.985_600_3 * n).truncatingRemainder(dividingBy: 360) * rad
        let eclipticLongitude = (meanLongitude + 1.915 * sin(meanAnomaly) + 0.020 * sin(2 * meanAnomaly)) * rad
        let obliquity = (23.439 - 0.000_000_4 * n) * rad

        let rightAscension = atan2(cos(obliquity) * sin(eclipticLongitude), cos(eclipticLongitude))
        let declination = asin(sin(obliquity) * sin(eclipticLongitude))

        let siderealHours = (18.697_374_558 + 24.065_709_824_419_08 * n).truncatingRemainder(dividingBy: 24)
        let hourAngle = (siderealHours * 15 + longitude) * rad - rightAscension
        let lat = latitude * rad
        return asin(sin(lat) * sin(declination) + cos(lat) * cos(declination) * cos(hourAngle)) / rad
    }

    static func sky(at date: Date, coordinate: CLLocationCoordinate2D) -> SkyState {
        let now = sunElevation(at: date, latitude: coordinate.latitude, longitude: coordinate.longitude)
        let later = sunElevation(at: date.addingTimeInterval(600), latitude: coordinate.latitude, longitude: coordinate.longitude)
        return SkyState(elevation: now, rising: later > now)
    }

    /// Aktuelle Uhrzeit – in Debug-Builds für UI-Tests über `AUDIT_FAKE_TIME` (ISO 8601) verstellbar.
    static func now() -> Date {
        #if DEBUG
        if let value = ProcessInfo.processInfo.environment["AUDIT_FAKE_TIME"],
           let fake = ISO8601DateFormatter().date(from: value) {
            return fake
        }
        #endif
        return Date()
    }
}
