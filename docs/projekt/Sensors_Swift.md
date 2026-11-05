# Sensoren in Swift - Umfassende Dokumentation

## Übersicht

iOS bietet Zugriff auf verschiedene Hardware-Sensoren über das **Core Motion** und **CoreLocation** Frameworks. Diese Sensoren ermöglichen es, Bewegungen, Orientierung und Position des Geräts zu erfassen.

---

## 1. Accelerometer (Beschleunigungsmesser)

### Aufbau und Funktion
- **Was es misst**: Lineare Beschleunigung in drei Achsen (x, y, z)
- **Messbereich**: Typischerweise ±8g (Gravitationsbeschleunigung)
- **Verwendung**: Erkennung von Bewegungen, Schütteln, Fallen, etc.

### Code Snippet
```swift
import CoreMotion

let motionManager = CMMotionManager()

// Prüfe ob Accelerometer verfügbar ist
if motionManager.isAccelerometerAvailable {
    motionManager.accelerometerUpdateInterval = 0.1 // 100ms
    
    motionManager.startAccelerometerUpdates(to: .main) { data, error in
        guard let data = data else { return }
        
        let x = data.acceleration.x
        let y = data.acceleration.y
        let z = data.acceleration.z
        
        print("X: \(x), Y: \(y), Z: \(z)")
    }
}

// Zum Stoppen
motionManager.stopAccelerometerUpdates()
```

---

## 2. Gyroscope (Gyroskop)

### Aufbau und Funktion
- **Was es misst**: Rotationsgeschwindigkeit um drei Achsen (x, y, z)
- **Messbereich**: Typischerweise ±2000°/s
- **Verwendung**: Erfassung von Drehbewegungen, 3D-Orientierung

### Code Snippet
```swift
import CoreMotion

let motionManager = CMMotionManager()

if motionManager.isGyroAvailable {
    motionManager.gyroUpdateInterval = 0.1
    
    motionManager.startGyroUpdates(to: .main) { data, error in
        guard let data = data else { return }
        
        let rotationX = data.rotationRate.x  // Rotation um X-Achse (rad/s)
        let rotationY = data.rotationRate.y  // Rotation um Y-Achse (rad/s)
        let rotationZ = data.rotationRate.z  // Rotation um Z-Achse (rad/s)
        
        print("Rotation - X: \(rotationX), Y: \(rotationY), Z: \(rotationZ)")
    }
}

motionManager.stopGyroUpdates()
```

---

## 3. Magnetometer (Magnetfeldmesser)

### Aufbau und Funktion
- **Was es misst**: Magnetische Feldstärke in drei Dimensionen
- **Verwendung**: Kompass-Funktionalität, Orientierungserkennung
- **Hinweis**: Wird über `deviceMotion` zugegriffen

### Code Snippet
```swift
import CoreMotion

let motionManager = CMMotionManager()

if motionManager.isDeviceMotionAvailable {
    motionManager.deviceMotionUpdateInterval = 0.1
    
    motionManager.startDeviceMotionUpdates(to: .main) { data, error in
        guard let data = data else { return }
        
        let magneticField = data.magneticField
        print("Magnetisches Feld - X: \(magneticField.field.x), Y: \(magneticField.field.y), Z: \(magneticField.field.z)")
        print("Genauigkeit: \(magneticField.accuracy)")
    }
}

motionManager.stopDeviceMotionUpdates()
```

---

## 4. Device Motion (Kombinierte Sensor-Daten)

### Aufbau und Funktion
- **Was es bietet**: Kombiniert Accelerometer, Gyroscope und Magnetometer
- **Gibt aus**: Attitude, Rotation Rate, Gravity, User Acceleration, Magnetic Field
- **Vorteil**: Bereits fusionierte und stabilisierte Daten

### Code Snippet
```swift
import CoreMotion

let motionManager = CMMotionManager()

if motionManager.isDeviceMotionAvailable {
    motionManager.deviceMotionUpdateInterval = 0.1
    
    // Wähle Reference Frame
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, error in
        guard let data = data else { return }
        
        // Attitude (Orientierung)
        let roll = data.attitude.roll    // Rotation um Z-Achse (rad)
        let pitch = data.attitude.pitch  // Rotation um X-Achse (rad)
        let yaw = data.attitude.yaw      // Rotation um Y-Achse (rad)
        
        print("Roll: \(roll), Pitch: \(pitch), Yaw: \(yaw)")
        
        // Gravity
        print("Gravity - X: \(data.gravity.x), Y: \(data.gravity.y), Z: \(data.gravity.z)")
        
        // User Acceleration (ohne Schwerkraft)
        print("User Accel - X: \(data.userAcceleration.x), Y: \(data.userAcceleration.y), Z: \(data.userAcceleration.z)")
    }
}

motionManager.stopDeviceMotionUpdates()
```

---

## 5. Barometer (Luftdruck-Sensor)

### Aufbau und Funktion
- **Was es misst**: Atmosphärischer Luftdruck
- **Verwendung**: Höhenberechnung, Wetter-Daten
- **Verfügbarkeit**: Ab iPhone 6s+

### Code Snippet
```swift
import CoreMotion

let altimeter = CMAltimeter()

if CMAltimeter.isRelativeAltitudeAvailable() {
    altimeter.startRelativeAltitudeUpdates(to: .main) { data, error in
        guard let data = data else { return }
        
        let relativeAltitude = data.relativeAltitude // in Meter
        let pressure = data.pressure // in Kilopascal
        
        print("Höhe: \(relativeAltitude)m, Druck: \(pressure)kPa")
    }
}

altimeter.stopRelativeAltitudeUpdates()
```

---

## 6. Proximity Sensor (Näherungssensor)

### Aufbau und Funktion
- **Was es misst**: Nähe des Objekts zum Display
- **Verwendung**: Display aus- und einschalten beim Telefonat
- **Hinweis**: Wird über `UIDevice` kontrolliert

### Code Snippet
```swift
import UIKit

// Proximity Monitoring aktivieren
UIDevice.current.isProximityMonitoringEnabled = true

// Notification abonnieren
NotificationCenter.default.addObserver(
    self,
    selector: #selector(proximityStateDidChange),
    name: UIDevice.proximityStateDidChangeNotification,
    object: UIDevice.current
)

@objc func proximityStateDidChange() {
    if UIDevice.current.proximityState {
        print("Objekt nah am Display")
    } else {
        print("Objekt weit weg vom Display")
    }
}
```

---

## 7. GPS / Location Services

### Aufbau und Funktion
- **Was es misst**: Geographische Position (Latitude, Longitude, Höhe)
- **Genauigkeit**: Variiert (bis zu ±5m mit A-GPS)
- **Verwendung**: Navigation, Standort-basierte Services

### Code Snippet
```swift
import CoreLocation

let locationManager = CLLocationManager()

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Berechtigungen anfordern
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        let altitude = location.altitude
        let accuracy = location.horizontalAccuracy
        
        print("Lat: \(latitude), Lon: \(longitude), Alt: \(altitude)m, Accuracy: ±\(accuracy)m")
    }
}
```

---

## 8. Pedometer (Schrittzähler)

### Aufbau und Funktion
- **Was es misst**: Anzahl der Schritte, Distanz, Etagen
- **Verfügbarkeit**: Ab iPhone 5s+
- **Verwendung**: Fitness-Tracking, Aktivitäts-Monitoring

### Code Snippet
```swift
import CoreMotion

let pedometer = CMPedometer()

if CMPedometer.isStepCountingAvailable() {
    let startDate = Date().addingTimeInterval(-60*60*24) // Letzte 24h
    
    pedometer.queryPedometerData(from: startDate, to: Date()) { data, error in
        guard let data = data else { return }
        
        let steps = data.numberOfSteps
        let distance = data.distance ?? 0
        let floors = data.floorsClimbed ?? 0
        
        print("Schritte: \(steps), Distanz: \(distance)m, Etagen: \(floors)")
    }
    
    // Live-Updates
    pedometer.startUpdates(from: Date()) { data, error in
        guard let data = data else { return }
        print("Aktuelle Schritte: \(data.numberOfSteps)")
    }
}
```

---

## 9. Ambient Light Sensor

### Aufbau und Funktion
- **Was es misst**: Umgebungshelligkeit
- **Verwendung**: Auto-Brightness, Face ID Authentifizierung
- **Hinweis**: Kein direkter API-Zugriff, wird vom System verwendet

---

## Koordinaten-System

```
       ┌─────────────────┐
       │       TOP       │
       │   (+Y Richtung) │
   ┌───┴─────────────────┴───┐
   │ L │                  │ R │
   │ E │      DISPLAY     │ I │
   │ F │                  │ G │
   │ T │                  │ H │
   │   │      (Z-Achse    │ T │
   │ (-X)  zeigt raus)    │(+X)│
   └───┬─────────────────┬───┘
       │      BOTTOM     │
       │   (-Y Richtung) │
       └─────────────────┘
```

---

## Best Practices

### 1. **Berechtigungen prüfen**
```swift
if motionManager.isAccelerometerAvailable {
    // Sensor verfügbar
}
```

### 2. **Update-Intervall optimieren**
```swift
// Zu häufig = hoher Stromverbrauch
// Zu selten = schlechte Präzision
motionManager.accelerometerUpdateInterval = 0.1 // 100ms ist meist gut
```

### 3. **Speicher freigeben**
```swift
// Immer stoppen, wenn nicht gebraucht
motionManager.stopAccelerometerUpdates()
```

### 4. **Background-Modes**
```swift
// In Info.plist hinzufügen für Background-Nutzung:
// - "motion" für Motion-Sensoren
// - "location" für GPS
// - "health" für HealthKit
```

### 5. **Sensor Fusion verwenden**
```swift
// Device Motion ist stabiler und genauer als einzelne Sensoren
motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { data, error in
    // Fused data
}
```

---

## Referenzen

- **Core Motion Framework**: https://developer.apple.com/documentation/coremotion
- **Core Location Framework**: https://developer.apple.com/documentation/corelocation
- **Apple Developer Dokumentation**: https://developer.apple.com/documentation/

---

## Zusammenfassung

| Sensor | Framework | Genauigkeit | Stromverbrauch | Verwendung |
|--------|-----------|------------|----------------|-----------|
| Accelerometer | CoreMotion | ±0.01g | Niedrig | Bewegungserkennung |
| Gyroscope | CoreMotion | ±0.05°/s | Niedrig | Rotation |
| Magnetometer | CoreMotion | ±1μT | Sehr niedrig | Kompass |
| GPS | CoreLocation | ±5m | Hoch | Navigation |
| Barometer | CoreMotion | ±1hPa | Sehr niedrig | Höhe |
| Pedometer | CoreMotion | Variabel | Niedrig | Schrittenzählung |
| Proximity | UIDevice | Binary | Sehr niedrig | Nähe zum Display |

