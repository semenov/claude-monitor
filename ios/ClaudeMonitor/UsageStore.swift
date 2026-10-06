import Foundation
import Observation
import WidgetKit

@MainActor
@Observable
final class UsageStore {
    var usage: Usage? = UsageAPI.cached // last known numbers, shown while the request runs
    var error: String?
    var isLoading = false

    var publicURL: String {
        get { UsageAPI.publicURL }
        set { UsageAPI.publicURL = newValue }
    }
    var token: String {
        get { UsageAPI.token }
        set { UsageAPI.token = newValue }
    }

    func refresh(force: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let fresh = try await UsageAPI.fetch(force: force)
            if fresh.limits != usage?.limits {
                WidgetCenter.shared.reloadAllTimelines()
            }
            usage = fresh
            error = nil
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            self.error = error.localizedDescription
        }
    }
}
