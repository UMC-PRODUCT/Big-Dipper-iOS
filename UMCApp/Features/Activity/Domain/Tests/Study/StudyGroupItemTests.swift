//
//  StudyGroupItemTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import Testing
@testable import ActivityDomain

@Suite("StudyGroupItem — Identifiable 파생 규칙 (도메인 규칙)")
struct StudyGroupItemTests {

    // MARK: - id derivation

    @Test("id는 serverID 와 동일하다")
    func idEqualsServerID() {
        let item = StudyGroupItem(
            serverID: "group_xyz",
            name: "iOS 스터디",
            iconName: "apple.logo",
            part: .ios
        )

        #expect(item.id == "group_xyz")
    }

    @Test("같은 serverID 의 두 인스턴스는 동등하다")
    func equalityByServerID() {
        let a = StudyGroupItem(serverID: "g_1", name: "A", iconName: "x", part: .ios)
        let b = StudyGroupItem(serverID: "g_1", name: "A", iconName: "x", part: .ios)

        #expect(a == b)
    }

    // MARK: - .all sentinel

    @Test("StudyGroupItem.all은 sentinel serverID '__all__' 를 갖는다")
    func allSentinelServerID() {
        #expect(StudyGroupItem.all.serverID == "__all__")
        #expect(StudyGroupItem.all.id == "__all__")
        #expect(StudyGroupItem.all.part == nil)
    }

    // MARK: - .preview sample

    @Test("StudyGroupItem.preview는 .all 을 첫 항목으로 포함하고 7개 파트를 모두 노출한다")
    func previewContainsAllAndSevenParts() {
        let preview = StudyGroupItem.preview

        #expect(preview.first == StudyGroupItem.all)
        #expect(preview.count == 8) // .all + 7 parts

        let coveredParts = Set(preview.compactMap { $0.part })
        #expect(coveredParts == Set(StudyPart.allCases))
    }
}
