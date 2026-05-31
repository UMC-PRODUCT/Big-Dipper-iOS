//
//  SocialSection.swift
//  AppProduct
//
//  Created by euijjang97 on 1/31/26.
//

import SwiftUI

/// 마이페이지의 소셜 계정 연동 섹션
///
/// 현재 연동되지 않은 소셜 계정만 표시하여 추가 연동을 유도합니다.
struct SocialSection: View {
    // MARK: - Property

    let sectionType: MyPageSectionType
    let socialType: [SocialType]
    /// 소셜 연동 버튼 탭 시 호출되는 클로저
    let onConnect: (SocialType) -> Void

    /// 연결되지 않은 소셜 타입만 필터링
    ///
    /// 전체 소셜 타입 중 이미 연동된 타입을 제외한 나머지를 반환합니다.
    private var availableSocialTypes: [SocialType] {
        SocialType.appConnectableCases.filter { !socialType.contains($0) }
    }

    // MARK: - Body

    var body: some View {
        if availableSocialTypes.isEmpty {
            EmptyView()
        } else {
            Section(content: {
                sectionContent
            }, header: {
                SectionHeaderView(title: sectionType.rawValue)
            })
        }
    }

    // MARK: - Private Function

    private var sectionContent: some View {
        ForEach(availableSocialTypes, id: \.self) { social in
            content(social)
        }
    }
    
    private func content(_ social: SocialType) -> some View {
        Button(action: {
            onConnect(social)
        }, label: {
            MyPageSectionRow(icon: social.imageResource, title: social.displayName, rightText: "연동하기")
        })
    }
}
