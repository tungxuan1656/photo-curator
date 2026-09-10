//
//  PhotoCuratorApp.swift
//  photo-curator
//
//  Created by Tùng Đoàn on 10/9/26.
//

import SwiftUI

@main
struct PhotoCuratorApp: App {
    @State private var appModel: AppModel

    init() {
        let container = AppContainer.live()
        _appModel = State(initialValue: AppModel(container: container))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
        }
    }
}
