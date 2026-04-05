//
//  ChallengerMissionCardHeader.swift
//  AppProduct
//
//  Created by jaewon Lee on 01/29/26.
//

import SwiftUI

// MARK: - Constants

fileprivate enum Constants {
    static let chevronIconSize: CGFloat = 14
    static let weekBadgeSize: CGFloat = 48
    static let weekBadgeCornerRadius: CGFloat = 12
}

// MARK: - ChallengerMissionCardHeader

/// 미션 카드 헤더 뷰
///
/// 주차 숫자 배지, 제목, 상태 텍스트, 펼치기/접기 버튼을 표시합니다.
struct ChallengerMissionCardHeader: View, Equatable {

    // MARK: - Property

    private let model: MissionCardModel
    private let isExpanded: Bool
    private let onToggle: () -> Void

    // MARK: - Initializer

    init(
        model: MissionCardModel,
        isExpanded: Bool,
        onToggle: @escaping () -> Void
    ) {
        self.model = model
        self.isExpanded = isExpanded
        self.onToggle = onToggle
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.model == rhs.model
        && lhs.isExpanded == rhs.isExpanded
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            WeekNumberBadge(week: model.week, status: model.status)
                .equatable()

            contentSection

            Spacer()

            chevronIcon
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if case .locked = model.status { return }
            onToggle()
        }
    }

    // MARK: - View Components

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            titleText
            statusText
        }
    }

    private var titleText: some View {
        Text(wrappedTitle)
            .appFont(.calloutEmphasis)
            .multilineTextAlignment(.leading)
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.status {
        case .pendingApproval, .pass, .fail:
            Text(model.status.displayText)
                .appFont(.footnote, color: model.status.foregroundColor)
        default:
            Text(model.missionTitle)
                .appFont(.footnote, color: .grey500)
                .lineLimit(1)
        }
    }

    private var chevronIcon: some View {
        Group {
            if case .locked = model.status {
                Image(systemName: "lock.fill")
            } else {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            }
        }
        .font(.system(size: Constants.chevronIconSize))
        .foregroundStyle(.grey400)
    }

    /// `-` 뒤에 zero-width space를 넣어 제목이 더 자연스럽게 줄바꿈되도록 조정합니다.
    ///
    /// 예: `1주차 - Spring Boot 시작하기`는 `-` 뒤에서 먼저 줄바꿈될 수 있어
    /// `Spring`과 `Boot`가 불필요하게 분리되는 경우를 줄입니다.
    private var wrappedTitle: String {
        model.title
            .replacingOccurrences(of: " - ", with: " - \u{200B}")
            .replacingOccurrences(of: "Spring Boot", with: "Spring\u{00A0}Boot")
    }
}

// MARK: - WeekNumberBadge

/// 주차 숫자 배지 (둥근 사각형 배경)
fileprivate struct WeekNumberBadge: View, Equatable {

    // MARK: - Property

    let week: Int
    let status: MissionStatus

    // MARK: - Body

    var body: some View {
        Text("\(week)")
            .appFont(.title3Emphasis, color: status.foregroundColor)
            .frame(width: DefaultConstant.iconSize, height: DefaultConstant.iconSize)
            .padding(DefaultConstant.iconPadding)
            .background(status.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
            .glassEffect(.clear, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ChallengerMissionCardHeader - All Status") {
    ScrollView {
        VStack(spacing: 16) {
            ForEach(
                Array(MissionPreviewData.allStatusMissions.enumerated()),
                id: \.element.id
            ) { index, mission in
                ChallengerMissionCardHeader(
                    model: mission,
                    isExpanded: index == 1
                ) { }
                .padding(DefaultConstant.defaultListPadding)
                .background(.white, in: .rect(cornerRadius: 24))
            }
        }
        .padding()
    }
    .background(Color.grey100)
}

#Preview("ChallengerMissionCardHeader - iOS Missions") {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(MissionPreviewData.iosMissions) { mission in
                ChallengerMissionCardHeader(
                    model: mission,
                    isExpanded: false
                ) { }
                .padding(DefaultConstant.defaultListPadding)
                .background(.white, in: .rect(cornerRadius: 24))
            }
        }
        .padding()
    }
    .background(Color.grey100)
}
#endif
