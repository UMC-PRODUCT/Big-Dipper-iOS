//
//  ProfileLinkSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// 사용자가 등록한 외부 링크(GitHub / LinkedIn / Blog)를 열어 주는 섹션.
///
/// 등록된 링크가 없으면 이동 대신 프로필에서 링크를 추가하도록 안내합니다.
public struct ProfileLinkSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let profileLink: [ProfileLink]
    @Binding private var alertPrompt: AlertPrompt?
    @Environment(\.openURL) private var openURL

    // MARK: - Init

    public init(
        sectionType: MyPageSectionType = .profileLink,
        profileLink: [ProfileLink],
        alertPrompt: Binding<AlertPrompt?>
    ) {
        self.sectionType = sectionType
        self.profileLink = profileLink
        self._alertPrompt = alertPrompt
    }

    // MARK: - Body

    public var body: some View {
        Section(content: {
            sectionContent
        }, header: {
            SectionHeaderView(title: sectionType.rawValue, weight: .semibold)
        })
    }

    // MARK: - Function

    private var sectionContent: some View {
        ForEach(SocialLinkType.allCases, id: \.rawValue) { linkType in
            content(linkType)
        }
    }

    private func content(_ linkType: SocialLinkType) -> some View {
        Button(action: {
            open(linkType)
        }, label: {
            // 시안(12736:32709)은 SF Symbol 타일이 아니라 서비스 브랜드 이미지를 쓴다.
            MyPageSectionRow(
                brandIcon: linkType.brandIcon,
                title: linkType.title,
                rightImage: "arrow.up.right"
            )
        })
        .buttonStyle(.borderless)
    }

    private func open(_ linkType: SocialLinkType) {
        let rawURL = profileLink.first(where: { $0.type == linkType })?.url ?? ""

        guard let url = Self.normalizedURL(rawURL) else {
            alertPrompt = AlertPrompt(
                title: "\(linkType.title)\(linkType.objectParticle) 열 수 없어요",
                message: "아직 등록된 링크가 없습니다. 프로필에서 링크를 추가해 주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        openURL(url)
    }

    /// 스킴이 없는 입력(`github.com/foo`)도 열리도록 `https://` 를 보완합니다.
    private static func normalizedURL(_ rawURL: String) -> URL? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let directURL = URL(string: trimmed), directURL.scheme != nil {
            return directURL
        }

        return URL(string: "https://\(trimmed)")
    }
}
