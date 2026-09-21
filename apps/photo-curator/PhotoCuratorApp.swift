//
//  PhotoCuratorApp.swift
//  photo-curator
//
//  Created by Tùng Đoàn on 10/9/26.
//

import SwiftData
import SwiftUI

@main
struct PhotoCuratorApp: App {
    @State private var appModel: AppModel
    private let workspaceModelContainer: ModelContainer

    init() {
        let container = AppContainer.live()
        workspaceModelContainer = container.workspaceModelContainer
        _appModel = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .environment(appModel.modelInstallation)
                .environment(\.locale, appModel.appLanguage.locale)
        }
        .modelContainer(workspaceModelContainer)
    }
}
