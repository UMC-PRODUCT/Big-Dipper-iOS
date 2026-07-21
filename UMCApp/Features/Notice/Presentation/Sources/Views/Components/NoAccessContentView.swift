//
//  NoAccessContentView.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/20/26.
//

import SwiftUI
import CoreDesignSystem

// MARK: - NoAccessContentView

struct NoAccessContentView: View {

    // MARK: - Constants

    fileprivate enum Constants {
        static let iconSystemName: String = "person.badge.shield.checkmark"
        static let iconSize: CGFloat = 56
        static let title: String = "접근 권한이 없어요"
        static let description: String = "이 공지는 특정 운영진에게만 보여요.\n권한이 바뀌었다면 잠시 후 다시 확인해 주세요."
        static let accessibilityCombinedLabel: String = "접근 권한이 없어요. 이 공지는 특정 운영진에게만 보입니다."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            lockIcon
            Spacer().frame(height: DefaultSpacing.spacing16)
            Text(Constants.title)
                .appFont(.callout, weight: .semibold)
                .multilineTextAlignment(.center)
            Spacer().frame(height: DefaultSpacing.spacing8)
            Text(Constants.description)
                .appFont(.subheadline)
                .foregroundStyle(Color.grey600)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Constants.accessibilityCombinedLabel)
    }

    // MARK: - Sub Views

    private var lockIcon: some View {
        Image(systemName: Constants.iconSystemName)
            .font(.system(size: Constants.iconSize))
            .foregroundStyle(Color.grey400)
            .accessibilityHidden(true)
    }
}
