//
//  MyActiveLogSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import SwiftUI

/// 내가 쓴 글 / 댓글 단 글 / 스크랩으로 이동하는 활동 내역 섹션.
public struct MyActiveLogSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let onSelect: (MyActiveLogsType) -> Void

    // MARK: - Init

    public init(
        sectionType: MyPageSectionType = .myActiveLogs,
        onSelect: @escaping (MyActiveLogsType) -> Void
    ) {
        self.sectionType = sectionType
        self.onSelect = onSelect
    }

    // MARK: - Body

    public var body: some View {
        Section(content: {
            sectionContent
        }, header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }

    // MARK: - Function

    private var sectionContent: some View {
        ForEach(MyActiveLogsType.allCases) { log in
            content(log)
        }
    }

    private func content(_ log: MyActiveLogsType) -> some View {
        Button(action: {
            onSelect(log)
        }, label: {
            MyPageSectionRow(
                systemIcon: log.icon,
                title: log.rawValue,
                rightImage: "chevron.right",
                iconBackgroundColor: log.backgroundColor
            )
        })
        .buttonStyle(.borderless)
    }
}
