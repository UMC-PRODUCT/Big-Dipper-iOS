//
//  ParticipantAttendanceRow.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - ParticipantAttendanceRow

/// 출석 현황 상세의 참여자 카드
///
/// 프로필·이름/닉네임·학교·GPS 인증 여부·사유를 표시하고, 우측에 상태 뱃지를 둡니다.
/// 승인/반려 처리 중(`isProcessing`)이면 뱃지 자리를 `ProgressView` 로 대체합니다.
///
/// 표시 내용이 모두 데이터 파생이라 `.equatable()` 로 body 재평가를 스킵해도 안전합니다
/// (시각 파생 표시가 있는 ``AttendanceScheduleRow`` 와 대비).
struct ParticipantAttendanceRow: View, Equatable {

    // MARK: - Property

    let participant: ParticipantAttendance
    let isProcessing: Bool

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            avatar

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                nameRow
                schoolRow

                // 빈 문자열 사유는 "사유: " 만 남으므로 표시하지 않는다
                // (스와이프 액션의 사유 버튼 노출 조건과 동일 기준).
                if let reason = participant.excuseReason, !reason.isEmpty {
                    Text("사유: \(reason)")
                        .appFont(.caption1, color: .grey600)
                        .lineLimit(Constants.reasonLineLimit)
                }
            }

            Spacer()

            if isProcessing {
                ProgressView()
                    .frame(width: Constants.avatarSize, height: Constants.avatarSize)
            } else {
                AttendanceStatusBadge(status: participant.attendanceStatus)
            }
        }
        .padding(DefaultSpacing.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    // MARK: - View Components

    private var avatar: some View {
        RemoteImage(
            urlString: participant.profileImageURL,
            size: CGSize(width: Constants.avatarSize, height: Constants.avatarSize)
        )
    }

    private var nameRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(participant.name)
                .appFont(.callout, weight: .semibold, color: .grey700)
                .lineLimit(1)

            Text(participant.nickname)
                .appFont(.footnote, color: .grey500)
                .lineLimit(1)
        }
    }

    private var schoolRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(participant.schoolName)
                .appFont(.caption1, color: .grey500)
                .lineLimit(1)

            if participant.isLocationVerified {
                HStack(spacing: Constants.verifiedIconSpacing) {
                    Image(systemName: "location.fill")
                        .font(.system(size: Constants.verifiedIconSize))
                    Text("GPS 인증")
                        .appFont(.caption2, color: .green)
                }
                .foregroundStyle(.green)
            }
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let avatarSize: CGFloat = 40
    static let reasonLineLimit: Int = 2
    static let verifiedIconSize: CGFloat = 10
    static let verifiedIconSpacing: CGFloat = 2
}
