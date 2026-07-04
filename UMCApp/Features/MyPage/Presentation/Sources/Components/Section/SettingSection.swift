//
//  SettingSection.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI
import CoreUIComponents

/// 마이페이지 설정 섹션
///
/// 알림 설정, 위치 설정 등 iOS 시스템 설정으로 이동하는 버튼들을 표시합니다.
public struct SettingSection: View {
    // MARK: - Property
    
    private let sectionType: MyPageSectionType
    
    // MARK: - Body
    
    public var body: some View {
        Section(content: {
            sectionRow
        }, header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }
    
    // MARK: - Function
    
    @ViewBuilder
    private var sectionRow: some View {
        ForEach(SettingType.allCases, id: \.hashValue)
    }
}
