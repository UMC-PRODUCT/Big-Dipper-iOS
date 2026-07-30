//
//  ChallengerSessionCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 출석 가능한 세션 한 건을 표시하는 카드
///
/// 카테고리 아이콘과 제목·시간, 출석 상태 배지와 셰브론을 한 줄에 담습니다.
/// 상위 리스트에서 탭하면 지도·출석 버튼이 있는 상세가 펼쳐집니다.
struct ChallengerSessionCard: View, Equatable {

    // MARK: - Property

    private let session: Session
    private let isExpanded: Bool
    private let onTap: () -> Void

    private var info: SessionInfo {
        session.info
    }

    // MARK: - Init

    init(
        session: Session,
        isExpanded: Bool = false,
        onTap: @escaping () -> Void = {}
    ) {
        self.session = session
        self.isExpanded = isExpanded
        self.onTap = onTap
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.session.id == rhs.session.id
            && lhs.isExpanded == rhs.isExpanded
            && lhs.session.attendanceStatus == rhs.session.attendanceStatus
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let titleLineLimit: Int = 3
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            CardIconImage(
                image: info.category.symbol,
                color: info.category.color,
                isLoading: .constant(false)
            )
            contentSection
                .frame(maxWidth: .infinity, alignment: .leading)
            statusSection
        }
        .padding(DefaultConstant.defaultListPadding)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(.white)
            .glass()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    // MARK: - View Components

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text(info.title)
                .appFont(.callout, weight: .semibold, color: .grey900)
                .lineLimit(Constants.titleLineLimit)

            Text(info.startTime.timeRange(to: info.endTime))
                .appFont(.subheadline, color: .grey500)
        }
    }

    private var statusSection: some View {
        HStack {
            // 펼침 상태 + 승인 대기일 때 배지 숨김
            if !(isExpanded && session.attendanceStatus == .pendingApproval) {
                statusBadge
            }

            Image(
                systemName: isExpanded
                    ? DefaultConstant.chevronUpImage
                    : DefaultConstant.chevronDownImage
            )
            .foregroundStyle(Color.grey400)
        }
    }

    /// 출석 상태 배지
    private var statusBadge: some View {
        Text(session.attendanceStatus.displayText)
            .appFont(
                .caption1,
                weight: .semibold,
                color: session.attendanceStatus.fontColor
            )
            .padding(DefaultConstant.badgePadding)
            .background(session.attendanceStatus.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
            .glassEffect(
                .clear,
                in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius)
            )
    }
}

#if DEBUG
// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let info = SessionInfo(
        sessionId: SessionID(value: "preview"),
        iconName: "calendar.badge",
        title: "3주차 정기 세션",
        week: 3,
        startTime: .now,
        endTime: .now.addingTimeInterval(7_200),
        location: Coordinate(latitude: 37.5, longitude: 127.0)
    )
    let presentAttendance = Attendance(
        sessionId: info.sessionId,
        userId: UserID(value: "U-1"),
        type: .gps,
        status: .present,
        reason: nil
    )

    ZStack {
        Color.grey100.frame(height: 300)

        VStack(spacing: DefaultSpacing.spacing12) {
            ChallengerSessionCard(
                session: Session(info: info, initialAttendance: nil)
            )
            ChallengerSessionCard(
                session: Session(info: info, initialAttendance: presentAttendance)
            )
        }
        .padding()
    }
}
#endif
