import SwiftUI
import UIKit

struct SourceSelectionView: View {
    @Environment(AppModel.self) private var appModel
    @State private var showsAccessGuidance = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            Text(appModel.selectedIDs.count == 1 ? "1 photo selected" : "\(appModel.selectedIDs.count) photos selected")
                .font(.headline)
            if appModel.selectedIDs.count == 1 {
                Text("Photos Curator works best with 50+ photos, but you can curate any amount.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Text("Photos Curator will analyze these photos and propose a smaller album. Your originals stay unchanged.")
                .font(.footnote)
            Picker("Range", selection: $appModel.filter.preset) {
                Text("All").tag(SourcePreset.all)
                Text("Month").tag(SourcePreset.lastMonth)
                Text("3 Months").tag(SourcePreset.last3Months)
                Text("Year").tag(SourcePreset.lastYear)
                Text("Favorites").tag(SourcePreset.favorites)
            }
            .pickerStyle(.segmented)
            content
            VStack(spacing: 4) {
                Button("Continue") { appModel.continueToSummary() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!appModel.canContinueToSummary)
                if appModel.selectedIDs.isEmpty {
                    Text("Select at least 1 photo to continue")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 6)
        }
        .sheet(isPresented: $showsAccessGuidance) { AccessGuidanceSheet() }
        .navigationTitle("Choose source photos")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !appModel.filteredAssets.isEmpty {
                    Button(allFilteredSelected ? "Deselect All" : "Select All") {
                        if allFilteredSelected {
                            appModel.deselectAllFiltered()
                        } else {
                            appModel.selectAllFiltered()
                        }
                    }
                }
            }
        }
        .task { await appModel.loadSource() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .photoLibraryDidChange) {
                await appModel.refreshSourceAfterLibraryChange()
            }
        }
    }

    private var allFilteredSelected: Bool {
        let assets = appModel.filteredAssets
        guard !assets.isEmpty else { return false }
        return assets.allSatisfy { appModel.selectedIDs.contains($0.id) }
    }

    private func selectionLabel(isSelected: Bool, isFavorite: Bool) -> String {
        let state = isSelected ? "selected" : "not selected"
        if isFavorite {
            return "Photo, favorite, \(state)"
        }
        return "Photo, \(state)"
    }

    @ViewBuilder
    private var content: some View {
        switch (appModel.authorization, appModel.sourceState) {
        case (.denied, _), (.restricted, _), (_, .denied):
            Text("Photos Access Needed").font(.headline)
            Text("Allow photo access to choose images for curation.")
            Button("Open Settings") { appModel.openSettingsURL() }
                .buttonStyle(.borderedProminent)
            Button("Learn More") { showsAccessGuidance = true }
        case (_, .loading), (_, .idle):
            ProgressView("Loading photos…")
        case (_, .empty):
            Text("No Photos Available").font(.headline)
            Text("Add photos to your library or allow access to more photos, then try again.")
            if appModel.authorization == .limited {
                Button("Choose More Photos") { appModel.presentPicker() }
                    .buttonStyle(.borderedProminent)
            }
            Button("Try Again") { Task { await appModel.loadSource() } }
        case (_, .failed):
            Text("Couldn't load photos")
            Button("Retry") { Task { await appModel.loadSource() } }
        case (_, .loaded):
            if appModel.authorization == .limited {
                Text("Limited Photos Access — only shared photos appear.")
                    .font(.footnote)
                Button("Choose More Photos") { appModel.presentPicker() }
                    .font(.footnote)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(appModel.filteredAssets) { asset in
                        let isSelected = appModel.selectedIDs.contains(asset.id)
                        Button {
                            appModel.toggleSelection(asset.id)
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                AsyncPhotoThumbnail(assetID: asset.id, targetSizePixels: thumbPixels)
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .font(.title2)
                                    .foregroundStyle(isSelected ? Color.accentColor : .white)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(6)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                            }
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .accessibilityLabel(selectionLabel(isSelected: isSelected, isFavorite: asset.isFavorite))
                        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
                    }
                }
                .background {
                    PhotoGridDragSelector(
                        itemCount: appModel.filteredAssets.count,
                        columnsCount: 3,
                        spacing: 2,
                        onDragStart: { startIndex in
                            let asset = appModel.filteredAssets[startIndex]
                            let isSelected = appModel.selectedIDs.contains(asset.id)
                            return (isSelecting: !isSelected, initialSelection: appModel.selectedIDs)
                        },
                        onDragUpdate: { startIndex, currentIndex, isSelecting, initialSelection in
                            appModel.updateDragSelection(
                                initialSelected: initialSelection,
                                startIndex: startIndex,
                                currentIndex: currentIndex,
                                isSelecting: isSelecting
                            )
                        },
                        onDragEnd: {}
                    )
                }

                if appModel.filteredAssets.count < 15 {
                    VStack(spacing: 6) {
                        Label("How Curation Works", systemImage: "sparkles")
                            .font(.subheadline.bold())
                            .foregroundStyle(Color.accentColor)
                        Text(
                            "Photos Curator analyzes sharpness, expressions, and duplicate shots to find your "
                                + "best moments."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                    .padding()
                }
            }
            if appModel.unavailableCount > 0 {
                Text("\(appModel.unavailableCount) photos were unavailable and could not be analyzed.")
                    .font(.footnote)
            }
        }
    }
}
