//
//  ProfileCardSection.swift
//  MyPage
//
//  Created by 김동민 on 7/3/26.
//

import SwiftUI
import MyPageDomain
import CoreDI
import CoreDesignSystem
import CoreUIComponents

/// MyPage 상단에 표시되는 사용자 프로필 카드 컴포넌트
///
/// 프로필 이미지, 이름 / 닉네임, 학교 / 기수 / 파트 정보를 보여주며, 탭하면 상세 프로필 페이지로 이동합니다.
struct ProfileCardSection: View {
    // MARK: - property
    
    let profileData: ProfileData
    @Environment(\.di) var di
    
    private enum Constants {
        static let chevronSize: CGFloat = 9
        static let imageSize: CGSize = .init(width: 64, height: 64)
        static let chevron: String = "chevron.right"
    }
    
    //DI Container에서 주입받은 PathStore
//    private var pathStore: PathStore {
//        di.resolve(PathStore.self)
//    }
    
    // MARK: - Function
    
    public init(profileData: ProfileData) {
        self.profileData = profileData
    }
    
    internal var body: some View {
        Button(action: {
            //pathStore로 myPage(.myInfo(profileData: self.profileData)) 로 이동
        }, label: {
            HStack(spacing: DefaultSpacing.spacing12, content: {
                profileImage
                profileInfo
                Spacer()
                SectionRightImage(rightImage: Constants.chevron)
            })
        })
        
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
    
    
    /// 프로필 이미지 뷰(무지개 태두리 효과 포함)
    private var profileImage: some View {
//        RemoteImage()
        EmptyView()
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


