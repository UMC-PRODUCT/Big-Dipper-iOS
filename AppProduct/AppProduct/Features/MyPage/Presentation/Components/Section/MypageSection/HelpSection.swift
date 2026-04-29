//
//  HelpSection.swift
//  AppProduct
//
//  Created by euijjang97 on 1/28/26.
//

import SwiftUI

/// MyPage에서 지원센터(고객 지원, 문의 등)로 이동하는 Section 컴포넌트
struct HelpSection: View {
    // MARK: - Property

    @Environment(\.di) var di
    @Environment(ErrorHandler.self) private var errorHandler
    /// 섹션의 타입 (헤더 타이틀로 사용됨)
    let sectionType: MyPageSectionType
    let kakaoPlusManager: KakaoPlusManager = .init()
    

    /// DI Container에서 주입받은 NavigationRouter
    private var router: NavigationRouter {
        di.resolve(NavigationRouter.self)
    }

    private enum Constants {
        static let icon: String = "bubble.left.and.bubble.right"
        static let chevron: String = "chevron.right"
    }

    // MARK: - Function

    init(sectionType: MyPageSectionType) {
        self.sectionType = sectionType
    }

    // MARK: - Body

    var body: some View {
        Section(content: {
            sectionRow
        }, header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }

    /// 지원센터로 이동하는 Row 버튼
    private var sectionRow: some View {
        ForEach(HelpType.allCases, id: \.hashValue) { help in
            sectionContent(help)
        }
    }
    
    private func sectionContent(_ help: HelpType) -> some View {
        Button(action: {
            sectionAction(help)
        }, label: {
            MyPageSectionRow(systemIcon: help.icon, title: help.rawValue, rightImage: "arrow.up.right", iconBackgroundColor: help.color)
        })
    }
    
    private func sectionAction(_ help: HelpType) {
        switch help {
        case .inquery:
            kakaoPlusManager.openKakaoChannel(errorHandler: errorHandler)
        }
    }
}
