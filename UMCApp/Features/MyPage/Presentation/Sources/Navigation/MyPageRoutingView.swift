//
//  MyPageRoutingView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDI
import SwiftUI
import UMCFoundation

/// ``MyPageDestination``을 실제 화면으로 바꾸는 라우팅 뷰.
///
/// MyPage 탭 루트가 `.navigationDestination(for: MyPageDestination.self)`에서 사용한다.
/// 라우팅을 App이 아니라 이 모듈이 맡는 덕분에 목적지 화면을 `public`으로 열지 않아도 된다.
struct MyPageRoutingView: View {

    // MARK: - Property

    private let destination: MyPageDestination
    private let container: DIContainer

    // MARK: - Init

    init(destination: MyPageDestination, container: DIContainer) {
        self.destination = destination
        self.container = container
    }

    // MARK: - Body

    var body: some View {
        switch destination {
        case .activityLogs(let activityLogs):
            MyActivityLogsView(activityLogs: activityLogs)

        case .cardEdit(let profileData):
            MyPageProfileView(container: container, profileData: profileData)

        case .myActivePosts(let logType):
            MyActivePostsView(container: container, logType: logType)

        case .settings:
            MyPageSettingsView(container: container)
        }
    }
}
