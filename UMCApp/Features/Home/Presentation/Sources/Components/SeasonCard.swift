//
//  SeasonCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 7/9/26.
//

import CoreDesignSystem
import HomeDomain
import SwiftUI

/// 홈 화면 시즌 카드 — 소속 기수 목록 또는 누적 활동일을 표시한다.
struct SeasonCard: View {

    // MARK: - Property

    let seasonType: SeasonType

    // MARK: - Constants

    fileprivate enum Constants {
        static let cardSize = CGSize(width: 150, height: 120)
        static let iconSize: CGFloat = 24
        static let mainPadding = EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20)
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            icon
            Spacer(minLength: 0)
            title
            value
        }
        .padding(Constants.mainPadding)
        .frame(width: Constants.cardSize.width, height: Constants.cardSize.height, alignment: .leading)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
        )
    }

    // MARK: - Component

    private var icon: some View {
        Image(systemName: iconName)
            .font(.system(size: Constants.iconSize))
            .foregroundStyle(Color.indigo600)
    }

    private var title: some View {
        Text(titleText)
            .appFont(.caption1, weight: .semibold, color: .grey600)
    }

    @ViewBuilder
    private var value: some View {
        switch seasonType {
        case .days(let count):
            Text("\(count)일")
                .appFont(.title3, weight: .semibold, color: .grey900)
        case .gens(let gens):
            Text(gens.map { "\($0)기" }.joined(separator: ", "))
                .appFont(.callout, weight: .semibold, color: .grey900)
                .lineLimit(2)
        }
    }

    private var iconName: String {
        switch seasonType {
        case .days:
            "flame.fill"
        case .gens:
            "person.2.fill"
        }
    }

    private var titleText: String {
        switch seasonType {
        case .days:
            "누적 활동일"
        case .gens:
            "소속 기수"
        }
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: DefaultSpacing.spacing12) {
        SeasonCard(seasonType: .gens(["11", "12"]))
        SeasonCard(seasonType: .days(128))
    }
    .padding()
}
