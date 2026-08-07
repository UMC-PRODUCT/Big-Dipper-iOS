//
//  ChallengerCurriculumProgressCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - ChallengerCurriculumProgressCard

/// 커리큘럼 진행률 카드 컴포넌트
///
/// 파트명, 달성률, 커리큘럼 제목, 프로그레스바를 표시합니다.
struct ChallengerCurriculumProgressCard: View, Equatable {

    // MARK: - Property

    let model: CurriculumProgressModel

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model
    }

    // MARK: - Constants

    private enum Constants {
        static let progressBarHeight: CGFloat = 8
        static let iconName: String = "book.fill"
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: model.partColor.opacity(0.68), location: 0.0),
                .init(color: model.partColor.opacity(0.9), location: 0.32),
                .init(color: model.partColor, location: 0.62),
                .init(color: model.partColor.opacity(0.82), location: 1.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            headerSection
            titleSection
            progressSection
            footerSection
        }
        .padding(DefaultConstant.defaultCardPadding)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color.white)
            .cardShadow()
        }
    }

    // MARK: - View Components

    /// 헤더: 아이콘 + 파트명 + 달성률 퍼센트
    private var headerSection: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            CardIconImage(
                image: Constants.iconName,
                color: model.partColor,
                isLoading: .constant(false)
            )

            Text(model.partName)
                .appFont(.callout, weight: .semibold, color: model.partColor)

            Spacer()

            Text("\(model.progressPercentage)%")
                .appFont(.title3, weight: .semibold, color: model.partColor)
        }
    }

    /// 제목: 커리큘럼명
    private var titleSection: some View {
        Text(model.curriculumTitle)
            .appFont(.callout, weight: .semibold)
    }

    /// 프로그레스바: Gauge + linearCapacity
    private var progressSection: some View {
        Gauge(value: model.progress) {
            EmptyView()
        }
        .gaugeStyle(.linearCapacity)
        .tint(progressGradient)
        .frame(height: Constants.progressBarHeight)
    }

    /// 푸터: 완료 카운트
    private var footerSection: some View {
        HStack {
            Spacer()
            Text(model.completionText)
                .appFont(.footnote, color: .grey500)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerCurriculumProgressCard - Single") {
    ChallengerCurriculumProgressCard(
        model: CurriculumProgressModel(
            partName: "WEB PART CURRICULUM",
            curriculumTitle: "웹 프론트엔드 기초",
            completedCount: 2,
            totalCount: 8
        )
    )
    .padding()
    .background(Color.grey100)
}

#Preview("ChallengerCurriculumProgressCard - Multiple") {
    ScrollView {
        VStack(spacing: DefaultSpacing.spacing16) {
            ChallengerCurriculumProgressCard(
                model: CurriculumProgressModel(
                    partName: "WEB PART CURRICULUM",
                    curriculumTitle: "웹 프론트엔드 기초",
                    completedCount: 2,
                    totalCount: 8
                )
            )

            ChallengerCurriculumProgressCard(
                model: CurriculumProgressModel(
                    partName: "iOS PART CURRICULUM",
                    curriculumTitle: "Swift 기초 문법",
                    completedCount: 5,
                    totalCount: 10
                )
            )

            ChallengerCurriculumProgressCard(
                model: CurriculumProgressModel(
                    partName: "ANDROID PART CURRICULUM",
                    curriculumTitle: "Kotlin 입문",
                    completedCount: 10,
                    totalCount: 10
                )
            )
        }
        .padding()
    }
    .background(Color.grey100)
}
#endif
