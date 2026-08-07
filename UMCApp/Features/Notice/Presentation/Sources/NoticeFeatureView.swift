//
//  NoticeFeatureView.swift
//  NoticePresentation
//
//  Created by euijjang97 on 3/6/26.
//

import SwiftUI
import CoreDI
import UMCFoundation
import NoticeDomain

/// 공지 탭 진입점 — 루트 탭 셸의 `NavigationStack` 안에서 공지 목록을 표시한다.
public struct NoticeFeatureView: View {

    // MARK: - Property
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    private let onNoticeSelected: (NoticeDetail) -> Void
    private let onStaffNoticeSelected: () -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - onNoticeSelected: 공지 카드 탭 시 상세 화면 이동을 상위(App)에 위임하는 콜백.
    ///   - onStaffNoticeSelected: 운영진 공지 진입 버튼 탭 시 화면 이동을 상위(App)에 위임하는 콜백.
    ///
    ///   Notice Feature는 App 타깃의 전역 `NavigationDestination`을 참조할 수 없어(Feature → App
    ///   의존 방향 금지) 실제 push는 호출부(`RootTabView`)에서 수행한다.
    ///
    public init(
        onNoticeSelected: @escaping (NoticeDetail) -> Void,
        onStaffNoticeSelected: @escaping () -> Void
    ) {
        self.onNoticeSelected = onNoticeSelected
        self.onStaffNoticeSelected = onStaffNoticeSelected
    }

    // MARK: - Body
    public var body: some View {
        NoticeView(
            container: di,
            errorHandler: errorHandler,
            onNoticeSelected: onNoticeSelected,
            onStaffNoticeSelected: onStaffNoticeSelected
        )
    }
}
