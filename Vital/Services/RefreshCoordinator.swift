import Foundation
import Observation

/// Central coordinator for "refresh all tabs" events.
///
/// Before this existed, `TodayView`, `ActivityView`, and `MainTabView` each had
/// their own `onChange(of: scenePhase)` handlers that fired on every foreground
/// return. That meant 3× concurrent `refreshSession()` calls, duplicate HealthKit
/// syncs, and overlapping API loads on every app resume — which is what caused
/// the "stuck loading" feeling.
///
/// Now only `MainTabView` listens to `scenePhase`. After it finishes its sync
/// work, it calls `requestRefresh()`, which bumps `refreshToken`. Each tab view
/// observes the token and reloads its own data exactly once.
@MainActor
@Observable
final class RefreshCoordinator {
    /// Monotonic counter. Tab views reload when this changes.
    private(set) var refreshToken: Int = 0

    /// Bump the token so all observing views reload.
    func requestRefresh() {
        refreshToken &+= 1
    }
}
