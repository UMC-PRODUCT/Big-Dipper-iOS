//
//  StudyGroupItem.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/8/26.
//

import Foundation

struct StudyGroupItem: Identifiable, Equatable, Hashable {
    // MARK: - Property

    let serverID: String
    let name: String
    let iconName: String
    let part: StudyPart?

    /// serverID 기반 identity
    var id: String { serverID }

    // MARK: - Initializer

    init(
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

    static let all = StudyGroupItem(
        serverID: "__all__",
        name: "전체 스터디 그룹",
        iconName: "person.2.fill",
        part: nil
    )

    static let preview: [StudyGroupItem] = [
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
}
