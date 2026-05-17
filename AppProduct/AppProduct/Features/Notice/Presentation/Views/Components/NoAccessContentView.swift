//
//  NoAccessContentView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import SwiftUI

// MARK: - NoAccessContentView

struct NoAccessContentView: View {

    // MARK: - Property

    let onGoBack: () -> Void
    let onRefresh: () async -> Void

    // MARK: - Constants

    fileprivate enum Constants {
        static let iconSystemName: String = "person.badge.shield.checkmark"
        static let iconSize: CGFloat = 56
        static let title: String = "접근 권한이 없어요"
        static let description: String = "이 공지는 특정 운영진에게만 보여요.\n권한이 바뀌었다면 새로고침해 보세요."
        static let primaryActionTitle: String = "공지 목록으로 돌아가기"
        static let secondaryActionTitle: String = "권한 정보 새로고침"
        static let accessibilityCombinedLabel: String = "접근 권한이 없어요. 이 공지는 특정 운영진에게만 보입니다."
        static let accessibilityCombinedHint: String = "권한이 바뀐 경우 새로고침 버튼을 두 번 탭하세요."
        static let secondaryActionHint: String = "운영진 권한을 다시 확인합니다."
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            messageBlock
            Spacer().frame(height: DefaultSpacing.spacing24)
            actionButtons
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    // MARK: - Sub Views

    private var messageBlock: some View {
        VStack(spacing: 0) {
            lockIcon
            Spacer().frame(height: DefaultSpacing.spacing16)
            Text(Constants.title)
                .appFont(.calloutEmphasis)
                .multilineTextAlignment(.center)
            Spacer().frame(height: DefaultSpacing.spacing8)
            Text(Constants.description)
                .appFont(.subheadline)
                .foregroundStyle(Color.grey600)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Constants.accessibilityCombinedLabel)
        .accessibilityHint(Constants.accessibilityCombinedHint)
    }

    private var lockIcon: some View {
        Image(systemName: Constants.iconSystemName)
            .font(.system(size: Constants.iconSize))
            .foregroundStyle(Color.grey400)
            .accessibilityHidden(true)
    }

    private var actionButtons: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            MainButton(Constants.primaryActionTitle) {
                onGoBack()
            }
            .buttonStyle(.glassProminent)

            Button {
                Task { await onRefresh() }
            } label: {
                Text(Constants.secondaryActionTitle)
                    .appFont(.footnote)
                    .foregroundStyle(Color.indigo500)
                    .padding(.vertical, DefaultSpacing.spacing8)
            }
            .accessibilityHint(Constants.secondaryActionHint)
        }
    }
}
