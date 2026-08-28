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
    private let receivedCardCount: String?
    private let onReceivedCards: () -> Void
    private let onCardEdit: (() -> Void)?
    private let isCardEditPending: Bool

    // MARK: - Init

    /// - Parameters:
    ///   - receivedCardCount: 받은 명함 수(서버 정수는 절대규칙 #2에 따라 String).
    ///     아직 못 세었으면(조회 전·실패) `nil` — "0장"이 아니라 "-"로 그린다 (#1222).
    ///   - onReceivedCards: 명함첩(받은 명함 그리드)으로 이동.
    ///   - onCardEdit: 명함 편집으로 이동. 편집에 필요한 프로필 스냅샷이 아직 없으면
    ///     (로딩 중·실패) `nil` — 행이 죽은 탭 없이 비활성화된다.
    ///   - isCardEditPending: `true`면 스냅샷 로딩 중이라는 뜻 — 행이 chevron 대신 진행
    ///     표시를 보여준다(`onCardEdit`이 `nil`이어도 무반응처럼 보이지 않게).
    public init(
        sectionType: MyPageSectionType = .businessCard,
        receivedCardCount: String?,
        onReceivedCards: @escaping () -> Void,
        onCardEdit: (() -> Void)?,
        isCardEditPending: Bool = false
    ) {
        self.sectionType = sectionType
        self.receivedCardCount = receivedCardCount
        self.onReceivedCards = onReceivedCards
        self.onCardEdit = onCardEdit
        self.isCardEditPending = isCardEditPending
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            // 시안 섹션 헤더는 Headline-emphasized(17 semibold) — `Figma 12632:87289`.
            SectionHeaderView(title: sectionType.rawValue, weight: .semibold)

            MyPageListCard {
                MyPageListRow(
                    systemIcon: "person.text.rectangle",
                    iconColor: MyPageListIconColor.green,
                    title: "받은 명함",
                    value: receivedCardCount.map { "\($0)장" } ?? "-",
                    action: onReceivedCards
                )

                MyPageListDivider()

                MyPageListRow(
                    systemIcon: "square.and.pencil",
                    iconColor: MyPageListIconColor.blue,
                    title: "명함 편집",
                    action: onCardEdit,
                    isPending: isCardEditPending
                )
            }
        }
    }
}
