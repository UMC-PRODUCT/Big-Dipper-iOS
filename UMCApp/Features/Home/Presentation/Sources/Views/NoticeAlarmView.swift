//
//  NoticeAlarmView.swift
//  HomePresentation
//
//  Created by JEONG on 7/30/26.
//

import CoreUIComponents
import SwiftUI

/// 알림 보관함 화면.
///
/// - Important: 아직 빈 상태만 표시하는 스텁이다. 실제 알림 내역은 SwiftData 모델
///   `NoticeHistoryData`와 `NoticeAlarmCard`에 의존하는데 둘 다 이식 전이므로, 이 슬라이스는
///   홈 툴바 → 알림 보관함 라우팅만 복구한다. 두 타입이 이식되면 `@Query`로 최신순 목록과
///   스와이프/전체 삭제 액션을 채운다.
public struct NoticeAlarmView: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let emptyTitle: String = "알림 내역이 없습니다."
        static let emptySystemImage: String = "bell.slash"
        static let emptyDescription: String = "새로운 소식이 도착하면 이곳에 표시됩니다."
    }

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: Constants.emptySystemImage,
            description: Text(Constants.emptyDescription)
        )
        .umcDefaultBackground()
        .navigation(naviTitle: NavigationTitle.Notice.alarmArchive, displayMode: .inline)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    NavigationStack {
        NoticeAlarmView()
    }
}
#endif
