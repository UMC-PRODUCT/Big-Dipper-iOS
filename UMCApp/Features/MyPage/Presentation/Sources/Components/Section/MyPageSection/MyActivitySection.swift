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
/// - 나의 스터디(MP-F10): 스터디 화면의 정본 소유자가 Activity 피처라 그 탭으로 옮긴다.
///   스터디 상세 목적지는 아직 없어 탭 전환까지만 하고 push 는 하지 않는다.
/// - 나의 활동・프로젝트(MP-F11): MyPage 안의 활동 이력 목록으로 push 한다. 「프로젝트」 축은
///   서버·도메인·DTO 에 엔티티가 없어 그릴 값 자체가 없다 — 행 제목만 시안대로 두고 목록은
///   활동 이력만 담는다.
///
/// 액션이 `nil`이면 ``MyPageListRow``가 탭 제스처를 아예 달지 않는다.
public struct MyActivitySection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    private let studyCount: String?
    private let activityCount: String?
    private let onStudyTap: (() -> Void)?
    private let onActivityTap: (() -> Void)?
    private let isActivityPending: Bool

    // MARK: - Init

    /// - Parameters:
    ///   - studyCount: 나의 스터디 수(서버 정수는 핵심규칙 #2에 따라 String).
    ///     아직 못 세었으면(조회 전·실패) `nil` — "0건"이 아니라 "-"로 그린다 (#1222).
    ///   - activityCount: 활동 이력 수. `studyCount`와 같은 `nil` 규칙을 따른다.
    ///   - onStudyTap: 나의 스터디 진입. 목적지가 준비되지 않았으면 `nil`.
    ///   - onActivityTap: 활동 이력 진입. 프로필 스냅샷이 아직 없으면 `nil`.
    ///   - isActivityPending: `true`면 목적지는 있는데 스냅샷을 기다리는 중이라는 뜻 —
    ///     행이 chevron 대신 진행 표시를 보여주고 탭을 막는다.
    public init(
        sectionType: MyPageSectionType = .myActivity,
        studyCount: String?,
        activityCount: String?,
        onStudyTap: (() -> Void)? = nil,
        onActivityTap: (() -> Void)? = nil,
        isActivityPending: Bool = false
    ) {
        self.sectionType = sectionType
        self.studyCount = studyCount
        self.activityCount = activityCount
        self.onStudyTap = onStudyTap
        self.onActivityTap = onActivityTap
        self.isActivityPending = isActivityPending
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            // 시안 섹션 헤더는 Headline-emphasized(17 semibold) — `Figma 12632:87301`.
            SectionHeaderView(title: sectionType.rawValue, weight: .semibold)

            MyPageListCard {
                MyPageListRow(
                    systemIcon: "books.vertical",
                    iconColor: MyPageListIconColor.orange,
                    title: "나의 스터디",
                    value: studyCount.map { "\($0)건" } ?? "-",
                    action: onStudyTap
                )

                MyPageListDivider()

                MyPageListRow(
                    systemIcon: "folder",
                    iconColor: MyPageListIconColor.teal,
                    title: "나의 활동 ・프로젝트",
                    value: activityCount.map { "\($0)건" } ?? "-",
                    action: onActivityTap,
                    isPending: isActivityPending
                )
            }
        }
    }
}
