import Foundation
import Network

/// Следит за доступностью сети через NWPathMonitor.
/// Нужен, чтобы показать плашку «Нет интернета» сразу при запуске,
/// когда ни один запрос ещё не успевал упасть.
@MainActor
final class NMNetworkMonitor: ObservableObject {
    static let shared = NMNetworkMonitor()

    @Published private(set) var isConnected: Bool = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NMNetworkMonitor")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}