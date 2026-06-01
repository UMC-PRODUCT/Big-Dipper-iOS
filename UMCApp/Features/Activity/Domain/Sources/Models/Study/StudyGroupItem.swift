//
//  StudyGroupItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 스터디 그룹 선택 항목
///
/// 운영자 화면에서 스터디 그룹 필터/선택 UI에 사용되는 경량 모델입니다.
public struct StudyGroupItem: Identifiable, Equatable, Hashable {

    // MARK: - Property

    public let serverID: String
    public let name: String
    public let iconName: String
    public let part: StudyPart?

    /// `serverID` 기반 identity
    public var id: String { serverID }

    // MARK: - Initializer

    public init(
        serverID: String,
        name: String,
        iconName: String,
        part: StudyPart? = nil
    ) {
        self.serverID = serverID
        self.name = name
        self.iconName = iconName
        self.part = part
    }

    // MARK: - Static Property

    /// "전체 스터디 그룹" 더미 항목
    public static let all = StudyGroupItem(
        serverID: "__all__",
        name: "전체 스터디 그룹",
        iconName: "person.2.fill",
        part: nil
    )

    #if DEBUG
    /// SwiftUI Preview / Mock 용 샘플 데이터 (전체 항목 + 7개 파트)
    ///
    /// - Important: `#if DEBUG` 가드 적용 — 릴리스 바이너리에 포함되지 않습니다.
    ///   본 fixture 에 의존하는 테스트도 동일하게 `#if DEBUG` 로 감쌉니다.
    public static let preview: [StudyGroupItem] = [
        .all,
        StudyGroupItem(
            serverID: "group_001",
            name: "iOS 스터디",
            iconName: "apple.logo",
            part: .ios
        ),
        StudyGroupItem(
            serverID: "group_002",
            name: "Android 스터디",
            iconName: "inset.filled.applewatch.case",
            part: .android
        ),
        StudyGroupItem(
            serverID: "group_003",
            name: "Web 스터디",
            iconName: "globe",
            part: .web
        ),
        StudyGroupItem(
            serverID: "group_004",
            name: "Spring 스터디",
            iconName: "leaf.fill",
            part: .spring
        ),
        StudyGroupItem(
            serverID: "group_005",
            name: "Node.js 스터디",
            iconName: "hexagon.fill",
            part: .nodejs
        ),
        StudyGroupItem(
            serverID: "group_006",
            name: "Design 스터디",
            iconName: "paintpalette.fill",
            part: .design
        ),
        StudyGroupItem(
            serverID: "group_007",
            name: "PM 스터디",
            iconName: "doc.text.fill",
            part: .pm
        )
    ]
    #endif
}
