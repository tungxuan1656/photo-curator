import Foundation
import UIKit

/// Single owner of memory-pressure observation. SwiftUI views and analysis
/// services never touch the notification directly; they read this state via
/// the batch loop (pressure is checked at batch boundaries only).
final class MemoryPressureObserver: Sendable {
    enum Level: Sendable {
        case normal, warning, critical
    }

    private let lock = NSLock()
    private var _level: Level = .normal
    private var observer: NSObjectProtocol?

    var level: Level {
        lock.withLock { _level }
    }

    func start() {
        lock.withLock {
            guard observer == nil else { return }
            observer = NotificationCenter.default.addObserver(
                forName: UIApplication.didReceiveMemoryWarningNotification,
                object: nil,
                queue: nil
            ) { [weak self] _ in
                self?.escalate()
            }
        }
    }

    func stop() {
        lock.withLock {
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            observer = nil
            _level = .normal
        }
    }

    /// Test and recovery seam: pressure clears only via an explicit call,
    /// never implicitly, so a transient warning cannot silently re-enable
    /// full preheat mid-run.
    func markRecovered() {
        lock.withLock { _level = .normal }
    }

    private func escalate() {
        lock.withLock {
            switch _level {
            case .normal:
                _level = .warning
            case .warning:
                _level = .critical
            case .critical:
                break
            }
        }
    }
}
