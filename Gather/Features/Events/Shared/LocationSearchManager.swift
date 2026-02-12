import SwiftUI
import MapKit
import Combine

/// Observable wrapper around MKLocalSearchCompleter for location search suggestions.
/// No CLLocationManager needed — MKLocalSearchCompleter works without location permission.
@MainActor
final class LocationSearchManager: ObservableObject {
    @Published var query = ""
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer = MKLocalSearchCompleter()
    private var delegate: CompleterDelegate?
    private var cancellable: AnyCancellable?

    init() {
        let delegate = CompleterDelegate { [weak self] results in
            self?.suggestions = results
            self?.isSearching = false
        }
        self.delegate = delegate
        completer.delegate = delegate
        completer.resultTypes = [.address, .pointOfInterest]

        cancellable = $query
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] value in
                guard let self else { return }
                if value.trimmingCharacters(in: .whitespaces).isEmpty {
                    self.suggestions = []
                    self.isSearching = false
                } else {
                    self.isSearching = true
                    self.completer.queryFragment = value
                }
            }
    }

    /// Perform a full search for a selected completion to get coordinates.
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.first
        } catch {
            return nil
        }
    }
}

// MARK: - Completer Delegate

private class CompleterDelegate: NSObject, MKLocalSearchCompleterDelegate {
    let onResults: ([MKLocalSearchCompletion]) -> Void

    init(onResults: @escaping ([MKLocalSearchCompletion]) -> Void) {
        self.onResults = onResults
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Silently fail — suggestions list stays empty
    }
}
