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
        static let iconSize: CGFloat = 24
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
            SectionHeaderView(title: header)
        })
    }

    // MARK: - Function

    private func linkField(_ type: SocialLinkType) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: type.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .foregroundStyle(type.color)

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
