import CoreLocation
import Foundation

/// Gets a single, approximate location to calculate local sunrise and sunset.
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case idle
        case locating
        case denied
        case failed
    }

    @Published private(set) var status: Status = .idle

    private let manager = CLLocationManager()
    private var completions: [(CLLocationCoordinate2D) -> Void] = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
    }

    var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            return true
        default:
            return false
        }
    }

    /// Requests one location. Without `prompting`, nothing happens unless access was already granted.
    func requestLocation(prompting: Bool, completion: @escaping (CLLocationCoordinate2D) -> Void) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            completions.append(completion)
            status = .locating
            manager.requestLocation()
        case .notDetermined:
            guard prompting else { return }
            completions.append(completion)
            status = .locating
            manager.requestWhenInUseAuthorization()
        default:
            if prompting {
                status = .denied
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard !completions.isEmpty else { return }
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        case .denied, .restricted:
            completions.removeAll()
            status = .denied
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let handlers = completions
        completions.removeAll()
        status = .idle
        handlers.forEach { $0(location.coordinate) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        completions.removeAll()
        status = .failed
    }
}
