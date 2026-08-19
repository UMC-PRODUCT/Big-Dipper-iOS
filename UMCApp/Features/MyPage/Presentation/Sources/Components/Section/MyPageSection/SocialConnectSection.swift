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
                // 시안 섹션 헤더는 Headline-emphasized(17 semibold) — `Figma 12736:32831`.
                SectionHeaderView(title: sectionType.rawValue, weight: .semibold)
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
            // 시안(12736:32832)은 SF Symbol 타일이 아니라 서비스 브랜드 타일 이미지를 쓴다.
            MyPageSectionRow(
                brandIcon: brandIcon(for: social),
                title: social.displayName,
                rightText: connectingSocial == social ? "연동 중" : "연동하기"
            )
        })
        .buttonStyle(.borderless)
        .disabled(connectingSocial != nil)
    }

    /// 소셜별 시안 타일 이미지. 구글은 연동 대상이 아니라(``SocialType/appConnectableCases``)
    /// 시안 타일이 없다 — 도달하지 않는 분기지만 switch 완전성을 위해 로그인 글리프로 채운다.
    private func brandIcon(for social: SocialType) -> Image {
        switch social {
        case .kakao:  return .kakaoColor
        case .apple:  return .appleColor
        case .google: return social.image
        }
    }
}
