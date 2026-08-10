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
/// 프로필 이미지, 이름 / 닉네임, 학교 / 기수 / 파트 정보를 보여줍니다.
///
/// - Note: 프로필 상세(``MyPageProfileView``)는 아직 본문이 비어 있어 이동 진입점을 열지 않는다.
///   상세 화면이 이식되면 이 카드를 탭 가능한 진입점으로 되돌린다.
struct ProfileCardSection: View {
    // MARK: - property

    let profileData: ProfileData

    private enum Constants {
        static let profileImageSize: CGSize = .init(width: 64, height: 64)
    }

    // MARK: - Function

    init(profileData: ProfileData) {
        self.profileData = profileData
    }

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12, content: {
            profileImage
            profileInfo
            Spacer()
        })
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


