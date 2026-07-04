//
//  AuthSection.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI
import UMCFoundation
import CoreUIComponents

/// 마이페이지의 인증 관련 섹션 (로그아웃, 회원탈퇴)
///
/// 사용자 인증 관련 작업을 처리하는 섹션으로, AlertPrompt를 통해 확인 다이얼로그를 표시합니다.
public struct AuthSection: View {
    // MARK: - Property
    
    private let sectionType: MyPageSectionType
    @Binding private var alertPrompt: AlertPrompt?
    @Environment(\.di) private var di
//    @Environment(\.appFlow) private var appFlow
    @Environment(ErrorHandler.self) private var errorHandler
    
//    private var pahtStore: PathStore {
//        di.resolve(PathStore.self)
//    }
    
    // MARK: - Body
    
    public var body: some View {
        Section(content: {
//            sectionContent
        }, header: {
//            SectionHeaderView(title: sectionType.rawValue)
        })
    }
    
    // MARK: - Function
    private var sectionContent: some View {
//        ForEach(AuthType.allCases, id: \.rawValue)
    }
}
