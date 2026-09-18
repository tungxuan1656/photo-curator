import Foundation
import Observation

/// Main-actor presentation state for the pinned Qwen model installation.
/// The installer remains the only owner of downloaded files and network work.
@MainActor
@Observable
final class ModelInstallationModel {
    let modelID = ModelManifest.qwen35TwoBFourBit.modelID
    let modelRevision = ModelManifest.qwen35TwoBFourBit.revision
    let modelSize = ModelManifest.qwen35TwoBFourBit.totalByteCount

    private let service: ModelInstallationService
    private var stateTask: Task<Void, Never>?
    private var installationTask: Task<Void, Never>?
    private var removalTask: Task<Void, Never>?

    private(set) var state: ModelInstallationState = .notInstalled
    private(set) var didRunStartupCheck = false
    var isSetupPromptPresented = false

    init(service: ModelInstallationService) {
        self.service = service
    }

    var isInstalled: Bool {
        if case .installed = state {
            return true
        }
        return false
    }

    var isDownloading: Bool {
        switch state {
        case .downloading, .verifying:
            return true
        case .notInstalled, .paused, .installed, .failed:
            return false
        }
    }

    var isBusy: Bool {
        installationTask != nil || removalTask != nil
    }

    var canStartDownload: Bool {
        !isBusy && !isInstalled
    }

    var completedBytes: Int64? {
        switch state {
        case let .downloading(completed, _), let .paused(completed, _):
            return completed
        case .notInstalled, .verifying, .installed, .failed:
            return nil
        }
    }

    var totalBytes: Int64? {
        switch state {
        case let .downloading(_, total), let .paused(_, total):
            return total
        case .notInstalled, .verifying, .installed, .failed:
            return nil
        }
    }

    var progressFraction: Double? {
        guard let completedBytes, let totalBytes, totalBytes > 0 else { return nil }
        return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
    }

    func startupCheck() async {
        guard !didRunStartupCheck else { return }
        startObserving()
        _ = await service.installedModel()
        state = await service.currentState()
        didRunStartupCheck = true
        if !isInstalled {
            isSetupPromptPresented = true
        }
    }

    func dismissSetupPrompt() {
        isSetupPromptPresented = false
    }

    func download() {
        guard canStartDownload else { return }
        isSetupPromptPresented = false
        let service = self.service
        installationTask = Task(priority: .utility) { [weak self] in
            do {
                _ = try await service.install()
            } catch {
                // The state stream publishes paused or failed for the UI.
            }
            self?.installationTask = nil
        }
    }

    func cancelDownload() {
        guard isDownloading else { return }
        let service = self.service
        Task {
            await service.cancel()
        }
    }

    func retryDownload() {
        download()
    }

    func remove() {
        guard isInstalled, !isBusy else { return }
        let service = self.service
        removalTask = Task { [weak self] in
            do {
                try await service.remove()
            } catch {
                // Removal is disabled while an installation task is active.
            }
            self?.removalTask = nil
        }
    }

    private func startObserving() {
        guard stateTask == nil else { return }
        let service = self.service
        stateTask = Task { [weak self] in
            let stream = await service.stateStream()
            for await nextState in stream {
                guard !Task.isCancelled else { return }
                self?.state = nextState
            }
        }
    }
}
