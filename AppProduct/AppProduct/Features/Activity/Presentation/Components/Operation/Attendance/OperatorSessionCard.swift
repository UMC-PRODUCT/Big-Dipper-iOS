
//
//  OperatorSessionCard.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/5/26.
//

import SwiftUI

/// 운영진 출석 관리 화면 세션 카드
///
/// 세션 정보와 출석 통계를 표시하며, 펼침 상태에서 승인 대기 명단을 보여줍니다.
struct OperatorSessionCard: View, Equatable {

    // MARK: - Actions

    /// 세션 카드 액션 그룹
    struct Actions {
        var onTap: () -> Void = {}
        var onLocationTap: () -> Void = {}
        var onPendingListTap: () -> Void = {}
        var onReasonTap: ((OperatorPendingMember) -> Void)?
        var onRejectTap: ((OperatorPendingMember) -> Void)?
        var onApproveTap: ((OperatorPendingMember) -> Void)?
    }

    // MARK: - Property

    private let sessionAttendance: OperatorSessionAttendance
    private let actions: Actions

    private var session: Session {
        sessionAttendance.session
    }

    private var info: SessionInfo {
        session.info
    }

    // MARK: - Initializer

    init(sessionAttendance: OperatorSessionAttendance, actions: Actions = .init()) {
        self.sessionAttendance = sessionAttendance
        self.actions = actions
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sessionAttendance == rhs.sessionAttendance
    }

    // MARK: - Constant

    fileprivate enum Constants {
        static let mapPinIconSize: CGSize = .init(width: 24, height: 24)
        static let mapButtonSize: CGFloat = 42
        static let titleLineLimit: Int = 2
        static let statusRadius: CGFloat = 8
        static let clockIconSize: CGSize = .init(width: 14, height: 14)
        static let backgroundOpacity: CGFloat = 0.15
    }


    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            headerSection

            if sessionAttendance.totalCount > 0 {
                OperatorAttendanceStatsRow(sessionAttendance: sessionAttendance)
                    .equatable()
            }

            statusSection
        }
        .padding(DefaultConstant.defaultCardPadding)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(.white)
            .glass()
        }
    }

    // MARK: - Function

    /// 상태별 섹션 전환
    ///
    /// - 진행전: "세션이 아직 시작되지 않았습니다"
    /// - 승인대기 있음: "N명의 승인 대기 명단 확인하기" (탭 가능)
    /// - 진행중 + 승인대기 없음: "현재 승인 대기가 없습니다"
    /// - 종료 + 승인대기 없음 + 100%: "모든 출석 승인이 완료되었습니다"
    /// - 종료 + 승인대기 없음 + <100%: 표시 안 함
    @ViewBuilder
    private var statusSection: some View {
        let style: OperatorStatusSectionStyle? = {
            switch currentSessionStatus {
            case .beforeStart:
                return .beforeStart
            case .inProgress:
                return sessionAttendance.pendingCount > 0 ? .pending : .inProgress
            case .ended:
                if sessionAttendance.pendingCount > 0 {
                    return .pending
                } else if sessionAttendance.attendanceRate >= 1.0 {
                    return .complete
                } else {
                    return nil
                }
            }
        }()

        if let style {
            statusSectionView(style: style)
        }
    }

    /// 통합 상태 섹션 뷰
    private func statusSectionView(style: OperatorStatusSectionStyle) -> some View {
        Button {
            if style.isEnabled {
                actions.onPendingListTap()
            }
        } label: {
            HStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: style.icon)
                    .renderingMode(.template)
                    .foregroundStyle(style.color)

                if style.isEnabled {
                    Text("\(sessionAttendance.pendingCount)명의 \(style.text)")
                        .appFont(.calloutEmphasis, color: style.color)
                } else {
                    Text(style.text)
                        .appFont(.calloutEmphasis, color: style.color)
                }

                if style.showChevron {
                    Spacer()

                    Image(systemName: DefaultConstant.chevronForwardImage)
                        .renderingMode(.template)
                        .foregroundStyle(style.color)
                }
            }
            .padding(ActivityConstants.statusCardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(
            style.isEnabled
            ? .regular.tint(style.backgroundColor).interactive()
            : .regular.tint(style.backgroundColor),
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
        .disabled(!style.isEnabled)
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DefaultSpacing.spacing12) {
//            SessionStatusIcon(status: currentSessionStatus)
//                .equatable()

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text(info.title)
                    .appFont(.calloutEmphasis, color: .black)
                    .lineLimit(Constants.titleLineLimit)

                HStack(spacing: DefaultSpacing.spacing8) {
                    sessionTime
                    status
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if currentSessionStatus == .beforeStart {
                Button(action: actions.onLocationTap) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.indigo300, .indigo600],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
                            )

                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .bold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .yellow)
                    }
                    .frame(
                        width: Constants.mapButtonSize,
                        height: Constants.mapButtonSize
                    )
                    .shadow(color: .indigo500.opacity(0.22), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .glassEffect(.clear.interactive(), in: .circle)
            }
        }
    }

    /// 상태 칩 (진행 중, 출결일, 예정)
    @ViewBuilder
    private var status: some View {
        Text(currentSessionStatus.displayText)
            .appFont(.footnote, color: currentSessionStatus.textColor)
    }

    /// 세션 상태 계산
    private var currentSessionStatus: OperatorSessionStatus {
        OperatorSessionStatus.from(startTime: info.startTime, endTime: info.endTime)
    }

    private var sessionTime: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Image(systemName: "clock")
                .resizable()
                .foregroundStyle(.gray)
                .frame(
                    width: Constants.clockIconSize.width,
                    height: Constants.clockIconSize.height)
            
            Text(formattedTime)
                .appFont(.footnote, color: .gray)
        }
    }
    /// 날짜 포맷팅
    private var formattedDate: String {
        info.startTime.toYearMonthDayWithWeekday()
    }
    
    /// 시간 포맷팅
    private var formattedTime: String {
        info.startTime.timeRange(to: info.endTime)
    }

}

// MARK: - Preview

#if DEBUG
#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(OperatorAttendancePreviewData.sessions) { session in
                OperatorSessionCard(sessionAttendance: session)
            }
        }
        .padding()
    }
    .background(Color.grey100)
}
#endif
