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
        // Given
        let item = StudyGroupItem(
            serverID: "group_xyz",
            name: "iOS 스터디",
            iconName: "apple.logo",
            part: .ios
        )

        // When
        let id = item.id

        // Then
        #expect(id == "group_xyz")
    }

    @Test("같은 serverID 의 두 인스턴스는 동등하다")
    func equalityByServerID() {
        // Given
        let a = StudyGroupItem(serverID: "g_1", name: "A", iconName: "x", part: .ios)
        let b = StudyGroupItem(serverID: "g_1", name: "A", iconName: "x", part: .ios)

        // When
        let areEqual = a == b

        // Then
        #expect(areEqual == true)
    }

    // MARK: - .all sentinel

    @Test("StudyGroupItem.all은 sentinel serverID '__all__' 와 nil part 를 갖는다")
    func allSentinelDefinition() {
        // Given
        let sentinel = StudyGroupItem.all

        // When
        let snapshot = (sentinel.serverID, sentinel.part)

        // Then
        #expect(snapshot.0 == "__all__")
        #expect(snapshot.1 == nil)
    }

    // MARK: - .preview sample

    @Test("StudyGroupItem.preview 의 첫 항목은 .all 이다")
    func previewFirstItemIsAll() {
        // Given
        let preview = StudyGroupItem.preview

        // When
        let first = preview.first

        // Then
        #expect(first == StudyGroupItem.all)
    }

    @Test("StudyGroupItem.preview 는 StudyPart 7개 파트를 모두 노출한다")
    func previewCoversAllSevenParts() {
        // Given
        let preview = StudyGroupItem.preview

        // When
        let coveredParts = Set(preview.compactMap { $0.part })

        // Then
        #expect(coveredParts == Set(StudyPart.allCases))
    }
}
