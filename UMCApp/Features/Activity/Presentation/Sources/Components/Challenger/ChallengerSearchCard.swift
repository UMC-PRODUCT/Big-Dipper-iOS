//
//  ChallengerSearchCard.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import SwiftUI

/// 챌린저 검색 결과 리스트의 단일 행.
///
/// 프로필·이름/닉네임/기수·학교를 보여주고, 선택 모드에서는 체크 아이콘으로 선택 상태를
/// 표시합니다.
struct ChallengerSearchCard: View, Equatable {

    // MARK: - Property

    /// 표시할 챌린저 정보
    let challenger: ChallengerInfo

    /// 선택 상태 체크 아이콘 표시 여부
    let showCheck: Bool

    /// 현재 행이 선택된 상태인지 여부
    let isSelected: Bool

    // MARK: - Constants

    fileprivate enum Constants {
        static let imageSize: CGFloat = 30
        static let checkImage: String = "checkmark.circle"
        static let uncheckImage: String = "circle"
    }

    // MARK: - Init

    init(
        challenger: ChallengerInfo,
        showCheck: Bool = false,
        isSelected: Bool = false
    ) {
        self.challenger = challenger
        self.showCheck = showCheck
        self.isSelected = isSelected
    }

    // MARK: - Equatable

    /// 행 식별 키와 선택 상태만 비교합니다 (리스트 재렌더 최소화).
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.challenger.selectionKey == rhs.challenger.selectionKey
            && lhs.showCheck == rhs.showCheck
            && lhs.isSelected == rhs.isSelected
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            profileImage
            challengerSummary
            Spacer()

            if showCheck {
                Image(systemName: isSelected ? Constants.checkImage : Constants.uncheckImage)
                    .foregroundStyle(isSelected ? Color.green : Color.grey500)
                    .font(.app(.title3))
            }
        }
    }

    // MARK: - View Components

    private var profileImage: some View {
        RemoteImage(
            urlString: challenger.profileImage ?? "",
            size: CGSize(width: Constants.imageSize, height: Constants.imageSize),
            cornerRadius: Constants.imageSize / 2
        )
    }

    private var challengerSummary: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(displayName)
                .appFont(.callout, weight: .semibold, color: .grey900)
            Text(challenger.schoolName)
                .appFont(.subheadline, color: .grey600)
        }
    }

    /// `이름/닉네임(9기)` — 기수를 모르면 기수 표기를 생략합니다.
    private var displayName: String {
        let base = "\(challenger.name)/\(challenger.nickname)"
        guard !challenger.gen.isEmpty else { return base }
        return "\(base)(\(challenger.gen)기)"
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerSearchCard") {
    List {
        ChallengerSearchCard(
            challenger: OperatorStudyPreviewData.challengers[0],
            showCheck: true,
            isSelected: true
        )
        ChallengerSearchCard(
            challenger: OperatorStudyPreviewData.challengers[1],
            showCheck: true
        )
    }
}
#endif
