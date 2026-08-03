//
//  ChallengerAttendanceSessionList.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityDomain
import CoreDesignSystem
import SwiftUI
import UMCFoundation

/// 출석 세션 목록을 표시하는 리스트 컴포넌트
///
/// 세션별 출석 카드와 확장 시 출석 상세 뷰를 함께 표시합니다.
struct ChallengerAttendanceSessionList: View, Equatable {

    // MARK: - Property

    private let sessions: [Session]
    private let expandedSessionId: Session.ID?
    private let attendanceViewModel: ChallengerAttendanceViewModel
    private let userId: UserID
    private let mapViewModelProvider: (Session) -> BaseMapViewModel?
    private let onSessionTap: (Session.ID) -> Void

    // MARK: - Init

    /// - Parameter mapViewModelProvider: 세션별 지도 상태 모델 제공자. 서버 일정 ID가
    ///   아직 해석되지 않은 세션은 `nil` 을 돌려주며, 상세는 지도 대신 플레이스홀더를 띄운다.
    init(
        sessions: [Session],
        expandedSessionId: Session.ID?,
        attendanceViewModel: ChallengerAttendanceViewModel,
        userId: UserID,
        mapViewModelProvider: @escaping (Session) -> BaseMapViewModel?,
        onSessionTap: @escaping (Session.ID) -> Void
    ) {
        self.sessions = sessions
        self.expandedSessionId = expandedSessionId
        self.attendanceViewModel = attendanceViewModel
        self.userId = userId
        self.mapViewModelProvider = mapViewModelProvider
        self.onSessionTap = onSessionTap
    }

    /// - Note: 일정 ID 가 뒤늦게 채워져 지도 모델이 생기는 전환은 이 비교에 포함되지 않는다.
    ///   지도는 카드를 펼칠 때(또는 세션 목록이 바뀔 때) 반영되며, 그 전까지 상세가 열려
    ///   있어도 플레이스홀더가 유지된다. 버튼 활성화는 `@Observable` 관찰로 즉시 따라온다.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sessions.map(\.id) == rhs.sessions.map(\.id)
            && lhs.expandedSessionId == rhs.expandedSessionId
            && lhs.userId == rhs.userId
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let listSpacing: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        LazyVStack(spacing: Constants.listSpacing) {
            ForEach(sessions) { session in
                sessionItem(for: session)
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private func sessionItem(for session: Session) -> some View {
        let isExpanded = expandedSessionId == session.id

        VStack(spacing: DefaultSpacing.spacing12) {
            ChallengerSessionCard(
                session: session,
                isExpanded: isExpanded
            ) {
                onSessionTap(session.id)
            }
            .equatable()

            if isExpanded {
                ChallengerAttendanceView(
                    mapViewModel: mapViewModelProvider(session),
                    attendanceViewModel: attendanceViewModel,
                    userId: userId,
                    session: session
                )
                .equatable()
                .transition(.asymmetric(
                    insertion: .scale(scale: DefaultConstant.transitionScale)
                        .combined(with: .opacity),
                    removal: .scale(scale: DefaultConstant.transitionScale)
                        .combined(with: .opacity)
                ))
            }
        }
    }
}

#if DEBUG
// MARK: - Preview

#Preview("두 번째 세션 펼침", traits: .sizeThatFitsLayout) {
    let sessions = AttendancePreviewData.mixedSessions.filter(\.isAttendanceAvailable)

    ZStack {
        Color.grey100.frame(height: 600)

        ChallengerAttendanceSessionList(
            sessions: sessions,
            expandedSessionId: sessions.first?.id,
            attendanceViewModel: AttendancePreviewData.viewModel(sessions: sessions),
            userId: AttendancePreviewData.userId,
            mapViewModelProvider: { _ in nil },
            onSessionTap: { _ in }
        )
        .padding()
    }
}
#endif
