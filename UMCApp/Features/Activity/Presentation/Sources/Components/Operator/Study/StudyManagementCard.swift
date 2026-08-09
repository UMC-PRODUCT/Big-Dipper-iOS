//
//  StudyManagementCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI

// MARK: - StudyManagementCard

/// 운영진 스터디 제출 현황 카드
///
/// 스터디원 1명을 한 카드로 묶고, 주차별 제출 상태를 카드 안의 행으로 펼칩니다.
/// 서버가 행을 스터디원 단위로 내려주고 주차를 `weeks` 배열에 담으므로, 카드 경계를 서버
/// 응답 구조와 맞춰 이름·학교·파트 같은 공통 정보가 주차마다 중복되지 않게 했습니다.
///
/// - Note: 레거시 `StudyManagementCard` 를 이식하면서 프로필을 `Image(assetName)` 에서
///   ``RemoteImage`` 로 바꿨습니다. 원본은 서버 URL 을 애셋 이름으로 넘겨(`Image("")`)
///   프로필이 어떤 값에서도 렌더링되지 않았습니다.
struct StudyManagementCard: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let cardCornerRadius: CGFloat = 20
        static let avatarSize: CGFloat = 40
        static let dividerHeight: CGFloat = 1
        static let schoolSeparatorWidth: CGFloat = 1
        static let schoolSeparatorHeight: CGFloat = 12
    }

    // MARK: - Property

    /// 스터디원 1명의 제출 현황
    let submission: StudyMemberSubmission

    /// 주차 행 탭 액션 (워크북 상세 진입)
    let onSelectWeek: (StudyManagementItem) -> Void

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            StudyManagementCardHeader(submission: submission)
                .equatable()

            // 주차 필터 결과가 비면 구분선 아래가 통째로 비어 카드가 깨져 보인다.
            let weekItems = submission.managementItems
            if !weekItems.isEmpty {
                Divider()
                    .frame(height: Constants.dividerHeight)

                VStack(spacing: 0) {
                    ForEach(weekItems) { item in
                        StudyManagementWeekRow(item: item) {
                            onSelectWeek(item)
                        }
                    }
                }
            }
        }
        .padding(DefaultConstant.defaultListPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: .rect(cornerRadius: Constants.cardCornerRadius)
        )
    }
}

// MARK: - StudyManagementCardHeader

/// 카드 상단 — 프로필 · 이름 + 파트 · 학교 | 소속 그룹
private struct StudyManagementCardHeader: View, Equatable {

    // MARK: - Property

    let submission: StudyMemberSubmission

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            avatarView

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                nameRow
                affiliationRow
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - View Components

    private var avatarView: some View {
        RemoteImage(
            urlString: submission.profileImageURL ?? "",
            size: CGSize(
                width: StudyManagementCard.Constants.avatarSize,
                height: StudyManagementCard.Constants.avatarSize
            ),
            cornerRadius: 0
        )
        .clipShape(Circle())
    }

    private var nameRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Text(submission.displayName)
                .appFont(.callout, weight: .semibold, color: .grey900)
                .lineLimit(1)

            InfoBadge(
                submission.partLabel,
                textColor: partColor,
                tintColor: partColor
            )
        }
    }

    @ViewBuilder
    private var affiliationRow: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            if let schoolName = submission.schoolName, !schoolName.isEmpty {
                Text(schoolName)
                    .appFont(.footnote, color: .grey600)
                    .lineLimit(1)

                Rectangle()
                    .frame(
                        width: StudyManagementCard.Constants.schoolSeparatorWidth,
                        height: StudyManagementCard.Constants.schoolSeparatorHeight
                    )
                    .foregroundStyle(Color.grey300)
            }

            Text(submission.studyGroupName)
                .appFont(.footnote, color: .grey500)
                .lineLimit(1)
        }
    }

    /// 파트 강조 색 — 서버가 모르는 파트를 보내면 중립 회색으로 떨어진다.
    private var partColor: Color {
        submission.part?.color ?? .grey500
    }
}

// MARK: - Preview

#if DEBUG
#Preview("제출 현황 카드") {
    ScrollView {
        GlassEffectContainer(spacing: DefaultSpacing.spacing16) {
            LazyVStack(spacing: DefaultSpacing.spacing16) {
                ForEach(OperatorStudyPreviewData.submissions) { submission in
                    StudyManagementCard(submission: submission, onSelectWeek: { _ in })
                }
            }
        }
        .padding()
    }
}
#endif
