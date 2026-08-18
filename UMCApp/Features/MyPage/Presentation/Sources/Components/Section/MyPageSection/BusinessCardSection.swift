//
//  BusinessCardSection.swift
//  MyPagePresentation
//
//  Created by One on 8/18/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI

/// v3 루트의 「명함 관리」 섹션 — 받은 명함 / 명함 편집.
public struct BusinessCardSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let receivedCardCount: String
    private let onReceivedCards: () -> Void
    private let onCardEdit: () -> Void

    // MARK: - Init

    /// - Parameters:
    ///   - receivedCardCount: 받은 명함 수(서버 정수는 절대규칙 #2에 따라 String).
    ///   - onReceivedCards: 명함첩(받은 명함 그리드)으로 이동.
    ///   - onCardEdit: 명함 편집(프로필 상세) 으로 이동.
    public init(
        sectionType: MyPageSectionType = .businessCard,
        receivedCardCount: String,
        onReceivedCards: @escaping () -> Void,
        onCardEdit: @escaping () -> Void
    ) {
        self.sectionType = sectionType
        self.receivedCardCount = receivedCardCount
        self.onReceivedCards = onReceivedCards
        self.onCardEdit = onCardEdit
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            SectionHeaderView(title: sectionType.rawValue)

            MyPageListCard {
                MyPageListRow(
                    systemIcon: "person.text.rectangle",
                    iconColor: MyPageListIconColor.green,
                    title: "받은 명함",
                    value: "\(receivedCardCount)장",
                    action: onReceivedCards
                )

                MyPageListDivider()

                MyPageListRow(
                    systemIcon: "square.and.pencil",
                    iconColor: MyPageListIconColor.blue,
                    title: "명함 편집",
                    action: onCardEdit
                )
            }
        }
    }
}
