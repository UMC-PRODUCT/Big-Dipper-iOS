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
    private let onScheduleSelected: (String) -> Void
    private let onAlarmHistoryTapped: () -> Void

    // MARK: - Init

    /// Home Feature는 App 타깃의 전역 `NavigationDestination`을 참조할 수 없어(Feature → App 의존
    /// 방향 금지) 화면 이동을 콜백으로 위임한다. 실제 push는 호출부(`RootTabView`)에서 수행한다.
    ///
    /// - Parameters:
    ///   - onNoticeSelected: 최근 공지 카드 탭 시 공지 상세 이동 콜백
    ///   - onScheduleSelected: 일정 카드 탭 시 일정 상세 이동 콜백 (일정 ID 전달)
    ///   - onAlarmHistoryTapped: 툴바 알림 버튼 탭 시 알림 보관함 이동 콜백
    public init(
        onNoticeSelected: @escaping (NoticeDetail) -> Void,
        onScheduleSelected: @escaping (String) -> Void,
        onAlarmHistoryTapped: @escaping () -> Void
    ) {
        self.onNoticeSelected = onNoticeSelected
        self.onScheduleSelected = onScheduleSelected
        self.onAlarmHistoryTapped = onAlarmHistoryTapped
    }

    // MARK: - Body

    public var body: some View {
        HomeView(
            container: di,
            onNoticeSelected: onNoticeSelected,
            onScheduleSelected: onScheduleSelected,
            onAlarmHistoryTapped: onAlarmHistoryTapped
        )
    }
}
