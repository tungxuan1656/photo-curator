/// Typed navigation routes for the G1 skeleton. Full route set grows in later stages.
/// Only `.permissionEducation` is pushed in G1; `.welcome` and `.home` are reserved
/// for later stages (do not treat them as dead code).
enum AppRoute: Hashable, Sendable {
    /// Reserved: first-run entry, shown as root (never pushed) in G1.
    case welcome
    /// Pushed from Welcome/Get Started and Home/Continue in G1.
    case permissionEducation
    /// Reserved: Home is the root (never pushed) in G1; later stages push it.
    case home
}
