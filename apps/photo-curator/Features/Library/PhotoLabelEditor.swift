import SwiftUI

/// Read/write label correction surface. All persistence is injected so the UI
/// cannot accidentally mutate albums, deletion staging, or Photos originals.
struct PhotoLabelEditor: View {
    let assetID: AssetID
    let automaticLabels: [PhotoLabelID]
    let effectiveLabels: [CatalogEffectiveLabelSnapshot]
    let overrides: [CatalogLabelOverrideIntent: Set<PhotoLabelID>]
    let personalLabels: [CatalogPersonalLabelSnapshot]
    let analysisState: CatalogLabelAnalysisSnapshot?
    let onOverride: (PhotoLabelID, CatalogLabelOverrideIntent) async throws -> Void
    let onRestore: (PhotoLabelID) async throws -> Void
    let onAssignPersonal: (UUID) async throws -> Void
    let onRemovePersonal: (UUID) async throws -> Void
    let onCreatePersonal: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var busyKey: String?
    @State private var errorMessage: String?
    @State private var showingNewLabel = false

    var body: some View {
        List {
            Section {
                Text("library.editor.description")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Section("library.editor.suggestedByAI") {
                ForEach(PhotoLabelTaxonomy.supportedLabels, id: \.id) { definition in
                    automaticRow(definition.id)
                }
            }
            Section("library.editor.personalLabels") {
                if personalLabels.isEmpty {
                    Text("library.editor.noPersonalLabels").foregroundStyle(.secondary)
                }
                ForEach(personalLabels) { label in
                    personalRow(label)
                }
                Button { showingNewLabel = true } label: {
                    Label("library.editor.addPersonalLabel", systemImage: "plus.circle.fill")
                }
            }
            if let analysisState, analysisState.outcome != .completed, analysisState.outcome != .completedEmpty {
                Section {
                    Label(analysisStatus(analysisState.outcome), systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Edit Labels")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "library.editor.saveErrorTitle",
            isPresented: Binding(get: { errorMessage != nil }, set: {
                if !$0 {
                    errorMessage = nil
                }
            })
        ) {
            Button("library.editor.done") { errorMessage = nil }
        } message: {
            Text("library.editor.saveErrorMessage")
        }
        .sheet(isPresented: $showingNewLabel) {
            NewPersonalLabelSheet { name in
                try await onCreatePersonal(name)
            }
        }
    }

    private func automaticRow(_ labelID: PhotoLabelID) -> some View {
        let isAutomatic = automaticLabels.contains(labelID)
        let isConfirmed = overrides[.confirm]?.contains(labelID) == true
        let isRejected = overrides[.reject]?.contains(labelID) == true
        let isEffective = effectiveLabels.contains { $0.labelID == labelID }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localizedLabel(labelID)).font(.body.weight(.medium))
                    Text(isAutomatic ? "library.editor.suggestedByAI" : "library.editor.notSuggested")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(stateTitle(isConfirmed: isConfirmed, isRejected: isRejected, isEffective: isEffective))
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Button("library.editor.confirmLabel") {
                    perform("confirm-\(labelID.rawValue)") {
                        try await onOverride(labelID, .confirm)
                    }
                }
                .disabled(busyKey != nil)
                Button("library.editor.incorrectLabel") {
                    perform("reject-\(labelID.rawValue)") {
                        try await onOverride(labelID, .reject)
                    }
                }
                .disabled(busyKey != nil)
                if isConfirmed || isRejected {
                    Button("library.editor.useAutomaticLabel") {
                        perform("restore-\(labelID.rawValue)") { try await onRestore(labelID) }
                    }
                    .disabled(busyKey != nil)
                }
            }
            .font(.caption.weight(.semibold))
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .contain)
    }

    private func personalRow(_ label: CatalogPersonalLabelSnapshot) -> some View {
        let assigned = effectiveLabels.contains { $0.personalLabelID == label.id }
        return HStack {
            Text(label.name)
            Spacer()
            Button(assigned ? "library.editor.remove" : "library.editor.add") {
                perform("personal-\(label.id.uuidString)") {
                    if assigned {
                        try await onRemovePersonal(label.id)
                    } else {
                        try await onAssignPersonal(label.id)
                    }
                }
            }
            .font(.subheadline.weight(.semibold))
            .accessibilityLabel(
                String(
                    localized: LocalizedStringResource(
                        assigned ? "library.editor.removePersonalLabel" : "library.editor.addPersonalLabelNamed",
                        defaultValue: assigned ? "Remove personal label \(label.name)" : "Add personal label \(label.name)"
                    )
                )
            )
        }
    }

    private func perform(_ key: String, action: @escaping () async throws -> Void) {
        busyKey = key
        Task {
            do {
                try await action()
                busyKey = nil
            } catch {
                busyKey = nil
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stateTitle(isConfirmed: Bool, isRejected: Bool, isEffective: Bool) -> String {
        if isRejected {
            return String(localized: "library.editor.state.incorrect")
        }
        if isConfirmed {
            return String(localized: "library.editor.state.confirmed")
        }
        return isEffective
            ? String(localized: "library.editor.state.suggested")
            : String(localized: "library.editor.state.notApplied")
    }

    private func analysisStatus(_ outcome: PhotoLabelAnalysisOutcome) -> String {
        switch outcome {
        case .pending: String(localized: "library.editor.analysis.pending")
        case .unavailable: String(localized: "library.editor.analysis.unavailable")
        case .stale: String(localized: "library.editor.analysis.stale")
        case .unsupported: String(localized: "library.editor.analysis.unavailable")
        case .completed, .completedEmpty: String(localized: "library.editor.analysis.loaded")
        }
    }
}

private struct NewPersonalLabelSheet: View {
    let onSave: (String) async throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("library.editor.labelName", text: $name)
                    .textInputAutocapitalization(.sentences)
            }
            .navigationTitle("library.editor.addPersonalLabel")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("library.editor.cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("library.editor.save") {
                        saving = true
                        Task {
                            do {
                                try await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                                saving = false
                                dismiss()
                            } catch {
                                saving = false
                                errorMessage = error.localizedDescription
                            }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving)
                }
            }
            .alert(
                "library.editor.saveErrorTitle",
                isPresented: Binding(get: { errorMessage != nil }, set: {
                    if !$0 {
                        errorMessage = nil
                    }
                })
            ) {
                Button("library.editor.retry") {
                    saving = true
                    Task {
                        do {
                            try await onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                            saving = false
                            dismiss()
                        } catch {
                            saving = false
                            errorMessage = error.localizedDescription
                        }
                    }
                }
                Button("library.editor.cancel", role: .cancel) { errorMessage = nil }
            } message: {
                Text("library.editor.saveErrorMessage")
            }
        }
    }
}
