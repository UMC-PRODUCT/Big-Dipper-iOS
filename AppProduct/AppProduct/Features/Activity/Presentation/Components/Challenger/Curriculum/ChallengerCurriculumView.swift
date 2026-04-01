//
//  ChallengerCurriculumView.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import SwiftUI

// MARK: - ChallengerCurriculumView

/// 커리큘럼 상세 뷰 (진행률 카드 + 미션 리스트)
///
/// 상단에 진행률 카드, 하단에 타임라인 형태의 미션 리스트를 표시합니다.
/// 미션 간 연결선은 카드 높이에 맞게 동적으로 확장됩니다.
struct ChallengerCurriculumView: View {

    // MARK: - Property
    @FocusState private var focusedMissionID: UUID?

    /// 커리큘럼 진행률 정보 (파트명, 완료 수, 전체 수)
    let curriculumModel: CurriculumProgressModel
    /// 미션 카드 목록 (주차별 미션 정보)
    let missions: [MissionCardModel]
    
    /// 미션 제출 시 호출되는 콜백
    /// - Parameters:
    ///   - mission: 제출 대상 미션
    ///   - type: 제출 타입 (링크 또는 완료만)
    ///   - link: 링크 URL (링크 타입일 경우)
    var onMissionSubmit: (MissionCardModel, MissionSubmissionType, String?) -> Void
    
    // MARK: - Constants

    private enum Constants {
        static let iconSize: CGFloat = 28
        static let connectorWidth: CGFloat = 2
        static let bottomPadding: CGFloat = 12
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: DefaultSpacing.spacing24) {
                // Header
                ChallengerCurriculumProgressCard(model: curriculumModel)
                    .equatable()
                // Mission List
                missionListSection
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
        .defaultScrollAnchor(.top)
        .contentMargins(
            .bottom,
            DefaultConstant.defaultContentBottomMargins,
            for: .scrollContent
        )
        .background(.white)
        .scrollDismissesKeyboard(.immediately)
    }

    // MARK: - View Components

    /// 미션 리스트 섹션 (타임라인 형태)
    private var missionListSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(missions.enumerated()), id: \.element.id) { index, mission in
                let isLast = index == missions.count - 1

                HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
                    // Left: Status Icon
                    ChallengerMissionStatusIcon(
                        status: mission.status,
                        weekNumber: mission.week
                    )
                    .equatable()

                    // Right: MissionCard
                    ChallengerMissionCard(
                        model: mission,
                        focusedMissionID: $focusedMissionID
                    ) { submissionType, link in
                        onMissionSubmit(mission, submissionType, link)
                    }
                    .padding(.bottom, isLast ? 0 : Constants.bottomPadding)
                }
                .overlay(alignment: .topLeading) {
                    // 연결선: overlay로 HStack 높이에 맞게 자동 확장
                    if !isLast {
                        Rectangle()
                            .fill(Color.grey200)
                            .frame(width: Constants.connectorWidth)
                            .frame(maxHeight: .infinity)
                            .padding(.top, Constants.iconSize)
                            .padding(.leading, (Constants.iconSize - Constants.connectorWidth) / 2)
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerCurriculumView - iOS") {
    struct PreviewWrapper: View {
        var body: some View {
            ChallengerCurriculumView(
                curriculumModel: CurriculumProgressModel(
                    partName: "iOS PART CURRICULUM",
                    curriculumTitle: "Swift 기초 문법",
                    completedCount: 2,
                    totalCount: 8
                ),
                missions: MissionPreviewData.iosMissions
            ) { mission, type, link in
                print("제출: \(mission.title) - \(type) - \(link ?? "없음")")
            }
        }
    }
    return PreviewWrapper()
}

#Preview("ChallengerCurriculumView - Web") {
    struct PreviewWrapper: View {
        var body: some View {
            ChallengerCurriculumView(
                curriculumModel: CurriculumProgressModel(
                    partName: "WEB PART CURRICULUM",
                    curriculumTitle: "웹 프론트엔드 기초",
                    completedCount: 5,
                    totalCount: 10
                ),
                missions: MissionPreviewData.webMissions
            ) { mission, type, link in
                print("제출: \(mission.title) - \(type) - \(link ?? "없음")")
            }
        }
    }
    return PreviewWrapper()
}

#Preview("ChallengerCurriculumView - All Status") {
    struct PreviewWrapper: View {
        var body: some View {
            ChallengerCurriculumView(
                curriculumModel: CurriculumProgressModel(
                    partName: "SERVER PART CURRICULUM",
                    curriculumTitle: "SpringBoot 실습",
                    completedCount: 3,
                    totalCount: 6
                ),
                missions: MissionPreviewData.allStatusMissions
            ) { mission, type, link in
                print("제출: \(mission.title) - \(type) - \(link ?? "없음")")
            }
        }
    }
    return PreviewWrapper()
}
#endif
