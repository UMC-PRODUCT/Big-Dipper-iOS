//
//  AttendanceScheduleRow.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - AttendanceScheduleRow

/// 운영진 출석 현황 목록의 일정 카드
///
/// 좌측 액센트 바 + 상태 배지로 진행 상태를, 하단에 출석/출석률/승인 대기 카운트를 표시합니다.
///
/// > Note: 의도적으로 `Equatable` 을 채택하지 않습니다. 상태 배지·액센트 색이 현재 시각
///   파생(``OperatorSessionStatus/from(startTime:endTime:now:)``)이라 `.equatable()` 로 body
///   재평가를 스킵하면 데이터가 그대로인 배경 폴링에서 "예정 → 진행중" 전환이 화면에 반영되지
///   않습니다. (레거시도 conformance 만 선언하고 `.equatable()` 은 적용하지 않아 실제 동작은
///   동일했습니다 — 이식하며 미사용 conformance 를 제거했습니다.)
struct AttendanceScheduleRow: View {

    // MARK: - Property

    let info: ScheduleAttendanceInfo

    private var status: OperatorSessionStatus {
        OperatorSessionStatus.from(startTime: info.startsAt, endTime: info.endsAt)
    }

    /// 진행중 카드만 은은한 indigo 틴트로 강조.
    ///
    /// (`Glass` 는 로컬 그림자 모디파이어와 이름이 겹칠 수 있어 SwiftUI 글래스 타입을
    ///  명시적으로 한정한다.)
    private var cardGlass: SwiftUICore.Glass {
        switch status {
        case .inProgress:
            return .regular
                .tint(.indigo500.opacity(Constants.inProgressTintOpacity))
                .interactive()
        default:
            return .regular.interactive()
        }
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            Capsule()
                .fill(status.listAccentColor)
                .frame(width: Constants.accentBarWidth)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                titleRow
                scheduleRow
                locationRow
                countRow
            }
        }
        .padding(DefaultSpacing.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            cardGlass,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
        .opacity(status == .ended ? Constants.endedOpacity : 1)
    }

    // MARK: - View Components

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(info.name)
                .appFont(
                    .callout,
                    weight: .semibold,
                    color: status == .ended ? .grey500 : .grey700
                )
                .lineLimit(1)

            Spacer()

            statusBadge
        }
    }

    private var statusBadge: some View {
        Text(status.listBadgeText)
            .appFont(.caption2, weight: .semibold, color: status.listAccentColor)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, DefaultSpacing.spacing4)
            .glassEffect(
                .clear.tint(status.listAccentColor.opacity(Constants.badgeTintOpacity)),
                in: Capsule()
            )
            .accessibilityLabel("상태 \(status.listBadgeText)")
    }

    private var scheduleRow: some View {
        AttendanceMetaLabel(systemImage: "calendar") {
            Text(
                AttendanceScheduleFormatter.dateRangeText(
                    from: info.startsAt,
                    to: info.endsAt,
                    style: .list
                )
            )
            .appFont(.footnote, color: .grey500)
        }
    }

    @ViewBuilder
    private var locationRow: some View {
        if let location = info.location {
            AttendanceMetaLabel(systemImage: "mappin.and.ellipse") {
                Text(location.locationName)
                    .appFont(.footnote, color: .grey500)
                    .lineLimit(1)
            }
        } else if info.isOnline {
            AttendanceMetaLabel(systemImage: "video") {
                Text("비대면")
                    .appFont(.footnote, color: .grey500)
            }
        }
    }

    private var countRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text("출석 \(info.presentCount) / \(info.totalCount)")
                .appFont(.footnote, color: .grey600)

            Text(
                AttendanceScheduleFormatter.attendanceRateText(
                    rate: info.attendanceRate,
                    totalCount: info.totalCount
                )
            )
            .appFont(.footnote, color: .grey500)

            if info.pendingCount > 0 {
                InfoBadge(
                    "대기 \(info.pendingCount)",
                    textColor: .orange500,
                    tintColor: .orange300,
                    glassVariant: .clear
                )
            }
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let accentBarWidth: CGFloat = 4
    static let endedOpacity: Double = 0.85
    static let badgeTintOpacity: Double = 0.18
    static let inProgressTintOpacity: Double = 0.10
}
