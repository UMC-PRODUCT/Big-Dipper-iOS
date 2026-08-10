//
//  ProfileCardSection.swift
//  MyPage
//
//  Created by 김동민 on 7/3/26.
//

import SwiftUI
import MyPageDomain
import CoreDesignSystem
import CoreUIComponents

/// MyPage 상단에 표시되는 사용자 프로필 카드 컴포넌트
///
/// 프로필 이미지, 이름 / 닉네임, 학교 / 기수 / 파트 정보를 보여주며 프로필 상세로 이동합니다.
struct ProfileCardSection: View {
    // MARK: - property

    let profileData: ProfileData
    private let onTap: () -> Void

    private enum Constants {
        static let profileImageSize: CGSize = .init(width: 64, height: 64)
    }

    // MARK: - Function

    /// - Parameter onTap: 프로필 상세로의 이동. 섹션은 `PathStore`를 알지 않고 탭 루트가 push한다.
    init(profileData: ProfileData, onTap: @escaping () -> Void) {
        self.profileData = profileData
        self.onTap = onTap
    }

    var body: some View {
        Button(action: onTap, label: {
            HStack(spacing: DefaultSpacing.spacing12, content: {
                profileImage
                profileInfo
                Spacer()
                Image(systemName: "chevron.right")
                    .appFont(.footnote, color: .grey500)
            })
            .contentShape(.rect)
        })
        .buttonStyle(.plain)
    }


    /// 프로필 이미지 뷰(무지개 태두리 효과 포함)
    private var profileImage: some View {
        RemoteImage(urlString: profileData.challengerInfo.profileImage ?? "", size: Constants.profileImageSize)
    }
    
    /// 프로필 정보(이름/닉네임, 학교/기수/파트)전체를 담는 VStack
    private var profileInfo: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4, content: {
            challengerName
            challengerPartInfo
        })
    }
    
    /// 챌린저 이름 및 닉네임을 표시하는 뷰(예: "정의찬 / 제옹")
    private var challengerName: some View {
        HStack(spacing: DefaultSpacing.spacing4, content: {
            Text(profileData.challengerInfo.name)
                .appFont(.body, color: .black)
            
            Text("/")
            
            Text(profileData.challengerInfo.nickname)
        })
        .appFont(.body, color: .black)
    }
    
    /// 챌린저의 학교, 기수, 파트 정보를 표시하는 뷰(예: "중앙대 • 11기 • Design")
    private var challengerPartInfo: some View {
        HStack(spacing: DefaultSpacing.spacing4, content: {
            Text(profileData.challengerInfo.schoolName)
            Text(" • ")
            Text("\(profileData.challengerInfo.gen)기")
            Text(" • ")
            Text(profileData.challengerInfo.part.name)
        })
    }
}


