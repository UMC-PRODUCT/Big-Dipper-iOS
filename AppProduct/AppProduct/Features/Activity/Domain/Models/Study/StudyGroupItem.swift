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

    /// serverID 기반 identity
    var id: String { serverID }

    // MARK: - Initializer

    init(
        serverID: String,
        name: String,
        iconName: String
    ) {
        self.serverID = serverID
        self.name = name
        self.iconName = iconName
    }

    // MARK: - Static Property

    static let all = StudyGroupItem(
        serverID: "__all__",
        name: "전체 스터디 그룹",
        iconName: "person.2.fill"
    )
}
