//
//  SocialConnectSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 아직 연동하지 않은 소셜 계정을 추가 연동하도록 유도하는 섹션.
///
/// 연동 해제는 프로필 화면의 ``ConnectionSocial`` 이 담당하므로 여기서는 추가만 다룹니다.
public struct SocialConnectSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let connectedSocials: [SocialType]
    private let connectingSocial: SocialType?
    private let onConnect: (SocialType) -> Void

    private var connectableSocials: [SocialType] {
        SocialType.appConnectableCases.filter { !connectedSocials.contains($0) }
    }

    // MARK: - Init

    public init(
        sectionType: MyPageSectionType = .socialConnect,
        connectedSocials: [SocialType],
        connectingSocial: SocialType?,
        onConnect: @escaping (SocialType) -> Void
    ) {
        self.sectionType = sectionType
        self.connectedSocials = connectedSocials
        self.connectingSocial = connectingSocial
        self.onConnect = onConnect
    }

    // MARK: - Body

    public var body: some View {
        if !connectableSocials.isEmpty {
            Section(content: {
                sectionContent
            }, header: {
                SectionHeaderView(title: sectionType.rawValue)
            })
        }
    }

    // MARK: - Function

    private var sectionContent: some View {
        ForEach(connectableSocials, id: \.rawValue) { social in
            content(social)
        }
    }

    private func content(_ social: SocialType) -> some View {
        Button(action: {
            onConnect(social)
        }, label: {
            MyPageSectionRow(
                systemIcon: "link",
                title: social.displayName,
                rightText: connectingSocial == social ? "연동 중" : "연동하기",
                iconBackgroundColor: social.color
            )
        })
        .buttonStyle(.borderless)
        .disabled(connectingSocial != nil)
    }
}
