import SwiftUI

struct SelectionSummaryView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss

    private var previewIDs: [AssetID] {
        if !appModel.confirmedSourceIDs.isEmpty {
            return Array(appModel.confirmedSourceIDs.prefix(4))
        }
        return Array(appModel.selectedIDs.prefix(4))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !previewIDs.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(previewIDs, id: \.self) { id in
                            AsyncPhotoThumbnail(assetID: id, targetSizePixels: CGSize(width: 200, height: 200))
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 8)
                }

                VStack(spacing: 6) {
                    Text(appModel.summary.selectedCount == 1
                        ? "Ready to curate 1 photo"
                        : "Ready to curate \(appModel.summary.selectedCount) photos")
                        .font(.title2.bold())
                    Text("Photos Curator will evaluate your photos and propose a smaller, polished album.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 14) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Smart Quality Scoring").font(.subheadline.bold())
                            Text("Evaluates sharpness, focus, lighting, and composition.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "sparkles")
                            .font(.title3)
                            .foregroundStyle(LinearGradient.curatorSunset)
                            .frame(width: 28)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Faces & Best Smiles").font(.subheadline.bold())
                            Text("Identifies open eyes, clear expressions, and best portraits.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "face.smiling")
                            .font(.title3)
                            .foregroundStyle(Color.curatorWarmAmber)
                            .frame(width: 28)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duplicate & Burst Pruning").font(.subheadline.bold())
                            Text("Groups similar shots and recommends the strongest moment.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.2.layers.3d")
                            .font(.title3)
                            .foregroundStyle(Color.curatorSunsetCoral)
                            .frame(width: 28)
                    }

                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("100% On-Device & Safe").font(.subheadline.bold())
                            Text("Analysis happens on this iPhone. Originals are never changed.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "lock.shield")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 28)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                if appModel.summaryHasICloudAssets {
                    Text("Some photos may need to download from iCloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if appModel.summary.unavailableCount > 0 {
                    let unavail = appModel.summary.unavailableCount
                    Text(unavail == 1
                        ? "1 photo was unavailable and could not be analyzed."
                        : "\(unavail) photos were unavailable and could not be analyzed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("This may take a while for large libraries.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    Button("Start Curation") {
                        appModel.startCuration()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(appModel.summary.selectedCount == 0)

                    Button("Change Photos") { dismiss() }
                        .font(.subheadline)
                }
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
        .navigationTitle("Summary")
    }
}
