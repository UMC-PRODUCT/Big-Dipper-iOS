//
//  ProfileLinkEditSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreUIComponents
import MyPageDomain
import SwiftUI

/// 외부 프로필 링크(GitHub / LinkedIn / Blog)를 TextField로 직접 편집하는 섹션.
///
/// 링크를 열기만 하는 ``ProfileLinkSection``과 달리 프로필 수정 화면 전용이다.
struct ProfileLinkEditSection: View, Equatable {

    // MARK: - Property

    @Binding private var profileLink: [ProfileLink]
    private let header: String

    private enum Constants {
        /// 시안 아이콘 틀 (`Figma item/MypageModify/link` 실측 32×32, 라운드 8).
        static let iconSize: CGFloat = 32
        static let iconRadius: CGFloat = 8
    }

    // MARK: - Init

    init(profileLink: Binding<[ProfileLink]>, header: String) {
        self._profileLink = profileLink
        self.header = header
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.header == rhs.header && lhs.profileLink == rhs.profileLink
    }

    // MARK: - Body

    var body: some View {
        Section(content: {
            ForEach(SocialLinkType.allCases, id: \.rawValue) { type in
                linkField(type)
            }
        }, header: {
            SectionHeaderView(title: header, weight: .semibold)
        })
    }

    // MARK: - Function

    private func linkField(_ type: SocialLinkType) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            // 시안(12804:30609)은 SF Symbol 틴트가 아니라 서비스 브랜드 이미지를 쓴다 —
            // 설정 화면 외부 링크 행(ProfileLinkSection)과 같은 에셋.
            type.brandIcon
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .clipShape(.rect(cornerRadius: Constants.iconRadius))
                // 장식 — 입력 필드 placeholder 가 이미 어떤 링크인지 말한다.
                .accessibilityHidden(true)

            TextField("", text: binding(for: type), prompt: Text(type.placeholder))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        }
    }

    /// 서버가 모든 링크 타입을 항상 내려주지는 않으므로, 없는 타입은 입력 시점에 추가한다.
    private func binding(for type: SocialLinkType) -> Binding<String> {
        Binding(
            get: { profileLink.first(where: { $0.type == type })?.url ?? "" },
            set: { newValue in
                if let index = profileLink.firstIndex(where: { $0.type == type }) {
                    profileLink[index].url = newValue
                } else {
                    profileLink.append(ProfileLink(type: type, url: newValue))
                }
            }
        )
    }
}
