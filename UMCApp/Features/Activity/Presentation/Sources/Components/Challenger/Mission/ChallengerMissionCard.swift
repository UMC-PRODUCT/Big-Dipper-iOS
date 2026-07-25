//
//  ChallengerMissionCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - ChallengerMissionCard (Container)

/// 미션 카드 메인 컴포넌트 (헤더 + 확장 콘텐츠)
struct ChallengerMissionCard: View {

    // MARK: - Property

    private let model: MissionCardModel

    @State private var isExpanded: Bool = false

    // MARK: - Initializer

    init(model: MissionCardModel) {
        self.model = model
    }

    // MARK: - Body

    var body: some View {
        ChallengerMissionCardPresenter(
            model: model,
            isExpanded: isExpanded,
            onToggleExpanded: {
                withAnimation(.easeInOut(duration: DefaultConstant.animationTime)) {
                    isExpanded.toggle()
                }
            }
        )
        .equatable()
    }
}

// MARK: - ChallengerMissionCardPresenter

fileprivate struct ChallengerMissionCardPresenter: View, Equatable {

    // MARK: - Property

    let model: MissionCardModel
    let isExpanded: Bool
    let onToggleExpanded: () -> Void

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model &&
        lhs.isExpanded == rhs.isExpanded
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            ChallengerMissionCardHeader(
                model: model,
                isExpanded: isExpanded,
                onToggle: onToggleExpanded
            )

            if isExpanded {
                ChallengerMissionCardContent(model: model)
                    .transition(.asymmetric(
                        insertion: .scale(scale: DefaultConstant.transitionScale)
                            .combined(with: .opacity),
                        removal: .scale(scale: DefaultConstant.transitionScale)
                            .combined(with: .opacity)))
            }
        }
        .padding(DefaultConstant.defaultListPadding)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.white)
            .glass()
        }
        .animation(
            .easeInOut(duration: DefaultConstant.animationTime),
            value: isExpanded)
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerMissionCard - All Status") {
    ScrollView {
        VStack(spacing: 20) {
            ForEach(MissionPreviewData.allStatusMissions) { mission in
                ChallengerMissionCard(model: mission)
            }
        }
        .padding()
    }
    .background(Color.grey100)
}

#Preview("ChallengerMissionCard - iOS Missions") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(MissionPreviewData.iosMissions) { mission in
                ChallengerMissionCard(model: mission)
            }
        }
        .padding()
    }
    .background(Color.grey100)
}

#Preview("ChallengerMissionCard - Single") {
    ChallengerMissionCard(model: MissionPreviewData.singleMission)
        .padding()
}
#endif
