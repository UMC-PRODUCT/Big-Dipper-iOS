//
//  ConnectionSocial.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents
import MyPageDomain
import UMCFoundation

/// 연동된 소셜 계정을 태그로 노출하고 탭하면 연동 해제를 요청하는 섹션입니다.
public struct ConnectionSocial: View {
    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let socialConnections: [SocialConnection]
    private let disconnectingSocialType: SocialType?
    private let onDisconnect: (SocialConnection) -> Void

    // MARK: - Body

    public var body: some View {
        if !socialConnections.isEmpty {
            Section(content: {
                socialTags
            }, header: {
                SectionHeaderView(title: sectionType.rawValue, weight: .semibold)
            })
        }
    }

    // MARK: - Function

    public init(
        sectionType: MyPageSectionType = .socialConnect,
        socialConnections: [SocialConnection],
        disconnectingSocialType: SocialType?,
        onDisconnect: @escaping (SocialConnection) -> Void
    ) {
        self.sectionType = sectionType
        self.socialConnections = socialConnections
        self.disconnectingSocialType = disconnectingSocialType
        self.onDisconnect = onDisconnect
    }

    private var socialTags: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            ForEach(socialConnections) { connection in
                socialTag(connection)
            }
        }
    }

    private func socialTag(_ connection: SocialConnection) -> some View {
        let social = connection.socialType

        return Button(action: {
            onDisconnect(connection)
        }, label: {
            HStack(spacing: DefaultSpacing.spacing4) {
                Text(social.displayName)
                Image(
                    systemName: disconnectingSocialType == social
                        ? "hourglass"
                        : "minus.circle.fill"
                )
                .font(.caption)
            }
            .appFont(.caption1, weight: .semibold, color: social.fontColor)
            .padding(.vertical, DefaultSpacing.spacing4)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .glassEffect(.clear.tint(social.color), in: .capsule)
        })
        .buttonStyle(.plain)
        .disabled(disconnectingSocialType != nil)
    }
}
