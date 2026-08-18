//
//  MyActivitySection.swift
//  MyPagePresentation
//
//  Created by One on 8/18/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI

/// v3 루트의 「나의 활동」 섹션 — 나의 스터디 / 나의 활동・프로젝트.
///
/// - Important: 두 행 모두 탭 목적지가 아직 명세에 없다(MP-F10·F11 미정). 죽은 탭 제스처를
///   만들지 않기 위해 두 행 모두 액션을 달지 않고 카운트만 표시한다. 목적지 연결은 후속 작업.
public struct MyActivitySection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let studyCount: String

    // MARK: - Init

    /// - Parameter studyCount: 나의 스터디 수(서버 정수는 절대규칙 #2에 따라 String).
    public init(
        sectionType: MyPageSectionType = .myActivity,
        studyCount: String
    ) {
        self.sectionType = sectionType
        self.studyCount = studyCount
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            SectionHeaderView(title: sectionType.rawValue)

            MyPageListCard {
                MyPageListRow(
                    systemIcon: "books.vertical",
                    iconColor: MyPageListIconColor.orange,
                    title: "나의 스터디",
                    value: "\(studyCount)건"
                )

                MyPageListDivider()

                MyPageListRow(
                    systemIcon: "folder",
                    iconColor: MyPageListIconColor.teal,
                    title: "나의 활동 ・프로젝트"
                )
            }
        }
    }
}
