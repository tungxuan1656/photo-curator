import SwiftUI
import UIKit

struct SourceSelectionView: View {
    @Environment(AppModel.self) private var appModel

    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
    private var thumbPixels: CGSize {
        let scale = UIScreen.main.scale
        let side = (UIScreen.main.bounds.width / 3) * scale
        let clamped = min(max(side, 200), 500)
        return CGSize(width: clamped, height: clamped)
    }

    var body: some View {
        @Bindable var appModel = appModel
        VStack {
            Text("\(appModel.selectedIDs.count) photos selected")
                .font(.headline)
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
            Button("Continue") { appModel.continueToSummary() }
                .buttonStyle(.borderedProminent)
                .disabled(!appModel.canContinueToSummary)
        }
        .navigationTitle("Choose source photos")
        .task { await appModel.loadSource() }
        .task {
            for await _ in NotificationCenter.default.notifications(named: .photoLibraryDidChange) {
                await appModel.refreshSourceAfterLibraryChange()
            }
        }
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
            Text("Photos Access Needed")
            Text("Allow photo access to choose images for curation.")
        case (_, .loading), (_, .idle):
            ProgressView("Loading photos…")
        case (_, .empty):
            Text("No Photos Available")
            Text("Add photos to your library or allow access to more photos, then try again.")
            Button("Try Again") { Task { await appModel.loadSource() } }
        case (_, .failed):
            Text("Couldn't load photos")
            Button("Retry") { Task { await appModel.loadSource() } }
        case (_, .loaded):
            if appModel.authorization == .limited {
                Text("Limited Photos Access — only shared photos appear. Use Choose More Photos in Home to add more.")
                    .font(.footnote)
            }
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(appModel.filteredAssets) { asset in
                        ZStack(alignment: .topTrailing) {
                            AsyncPhotoThumbnail(assetID: asset.id, targetSizePixels: thumbPixels)
                                .aspectRatio(1, contentMode: .fill)
                            let isSelected = appModel.selectedIDs.contains(asset.id)
                            Button {
                                appModel.toggleSelection(asset.id)
                            } label: {
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(selectionLabel(isSelected: isSelected, isFavorite: asset.isFavorite))
                        }
                    }
                }
            }
            if appModel.unavailableCount > 0 {
                Text("\(appModel.unavailableCount) photos were unavailable and could not be analyzed.")
                    .font(.footnote)
            }
        }
    }
}
