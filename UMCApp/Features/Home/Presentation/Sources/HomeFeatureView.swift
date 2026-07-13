//
//  HomeFeatureView.swift
//  HomePresentation
//
//  Created by euijjang97 on 3/6/26.
//

import CoreDI
import NoticeDomain
import SwiftUI

/// 홈 탭 진입점 — 루트 탭 셸의 `NavigationStack` 안에서 홈 대시보드를 표시한다.
public struct HomeFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    private let onNoticeSelected: (NoticeDetail) -> Void

    // MARK: - Init

    /// - Parameter onNoticeSelected: 최근 공지 카드 탭 시 상세 화면 이동을 상위(App)에 위임하는 콜백.
    ///   Home Feature는 App 타깃의 전역 `NavigationDestination`을 참조할 수 없어(Feature → App 의존
    ///   방향 금지) 실제 push는 호출부(`RootTabView`)에서 수행한다.
    public init(onNoticeSelected: @escaping (NoticeDetail) -> Void) {
        self.onNoticeSelected = onNoticeSelected
    }

    // MARK: - Body

    public var body: some View {
        HomeView(container: di, onNoticeSelected: onNoticeSelected)
    }
}
