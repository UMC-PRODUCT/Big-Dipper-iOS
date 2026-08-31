//
//  MyActivityLogsView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/29/26.
//

import CoreDomain
import CoreUIComponents
import SwiftUI

/// 「나의 활동 ・프로젝트」가 여는 활동 이력 목록 (MP-F11).
///
/// 읽기 전용이다 — 기록 추가는 「명함 편집」(``MyPageProfileView``)이 소유한다. ``ActiveLogs``는
/// `onAddTap`이 `nil`이면 추가 버튼을 그리지 않으므로 그대로 재사용한다.
///
/// - Important: 「프로젝트」 축은 서버·도메인·DTO 에 엔티티가 0건이라 그릴 값이 없다. 목록은
///   활동 이력만 담고, 그래서 섹션 헤더도 「활동 이력」이다.
struct MyActivityLogsView: View {

    // MARK: - Property

    private let activityLogs: [ActivityLog]

    private enum Constants {
        static let header = "활동 이력"
        static let emptyTitle = "아직 활동 이력이 없어요"
        static let emptyIcon = "folder"
        static let emptyDescription = "챌린저·운영진 활동이 등록되면 여기에 쌓여요."
    }

    // MARK: - Init

    init(activityLogs: [ActivityLog]) {
        self.activityLogs = activityLogs
    }

    // MARK: - Body

    var body: some View {
        Group {
            if activityLogs.isEmpty {
                ContentUnavailableView(
                    Constants.emptyTitle,
                    systemImage: Constants.emptyIcon,
                    description: Text(Constants.emptyDescription)
                )
            } else {
                Form {
                    ActiveLogs(rows: activityLogs, header: Constants.header)
                }
                // Form 의 불투명 systemGroupedBackground 가 `umcDefaultBackground` 를 덮어
                // 빈 상태와 목록 상태의 배경이 갈린다.
                .scrollContentBackground(.hidden)
            }
        }
        .navigation(naviTitle: NavigationTitle.MyPage.activityLogs, displayMode: .inline)
        .umcDefaultBackground()
    }
}
