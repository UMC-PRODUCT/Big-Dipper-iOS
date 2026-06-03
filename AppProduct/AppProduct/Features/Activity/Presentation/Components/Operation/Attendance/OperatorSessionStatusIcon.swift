//
//  OperatorSessionStatusIcon.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/6/26.
//

import SwiftUI

// MARK: - OperatorSessionStatusIcon

/// 세션 상태 아이콘 (운영진 세션 카드 좌측 상태 표시)
///
/// 세션 진행 상태를 아이콘으로 표시합니다.
struct OperatorSessionStatusIcon: View, Equatable {

    // MARK: - Property

    let status: OperatorSessionStatus

    // MARK: - Constants

    private enum Constants {
        static let iconSize: CGSize = .init(width: 36, height: 36)
        static let strokeWidth: CGFloat = 2
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.status == rhs.status
    }

    // MARK: - Body

    var body: some View {
        iconView
            .frame(
                width: Constants.iconSize.width,
                height: Constants.iconSize.height)
    }

    // MARK: - View Components

    @ViewBuilder
    private var iconView: some View {
        switch status {
        case .beforeStart:
            beforeStartIcon
        case .inProgress:
            inProgressIcon
        case .ended:
            endedIcon
        }
    }

    private var beforeStartIcon: some View {
        Image(systemName: "hourglass.circle.fill")
            .resizable()
            .foregroundStyle(status.iconColor)
    }

    private var inProgressIcon: some View {
        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90.circle.fill")
            .resizable()
            .foregroundStyle(status.iconColor)
    }

    private var endedIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .resizable()
            .foregroundStyle(status.iconColor)
            .symbolDrawOn(isActive: true)
    }
    
    
}

// MARK: - Preview

#if DEBUG
#Preview("OperatorSessionStatusIcon - All States", traits: .sizeThatFitsLayout) {
    VStack(spacing: DefaultSpacing.spacing24) {
        ForEach(OperatorSessionStatus.allCases, id: \.self) { status in
            HStack(spacing: DefaultSpacing.spacing16) {
                OperatorSessionStatusIcon(status: status)
                    .equatable()

                Text(status.displayText)
                    .appFont(.callout, color: .grey900)

                Spacer()
            }
        }
    }
    .padding()
//    .background(Color.grey100)
}

#Preview("OperatorSessionStatusIcon - Card Context") {
    VStack(spacing: DefaultSpacing.spacing12) {
        HStack(spacing: DefaultSpacing.spacing12) {
            OperatorSessionStatusIcon(status: .beforeStart)
            VStack(alignment: .leading) {
                Text("iOS 정규 세션 1주차")
                    .appFont(.calloutEmphasis)
                Text("진행전")
                    .appFont(.footnote, color: .grey500)
            }
            Spacer()
        }

        HStack(spacing: DefaultSpacing.spacing12) {
            OperatorSessionStatusIcon(status: .inProgress)
            VStack(alignment: .leading) {
                Text("iOS 정규 세션 2주차")
                    .appFont(.calloutEmphasis)
                Text("진행중")
                    .appFont(.footnote, color: .green)
            }
            Spacer()
        }

        HStack(spacing: DefaultSpacing.spacing12) {
            OperatorSessionStatusIcon(status: .ended)
            VStack(alignment: .leading) {
                Text("iOS 정규 세션 3주차")
                    .appFont(.calloutEmphasis)
                Text("종료됨")
                    .appFont(.footnote, color: .grey500)
            }
            Spacer()
        }
    }
    .padding()
    .background(Color.white)
    .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
    .padding()
    .background(Color.grey100)
}
#endif
