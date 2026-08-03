//
//  ParticipantAttendanceTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 7/25/26.
//

import Foundation
import Testing
@testable import ActivityDomain

// MARK: - Helpers

private func makeParticipant(
    name: String = "홍길동",
    nickname: String
) -> ParticipantAttendance {
    ParticipantAttendance(
        memberId: "1",
        name: name,
        nickname: nickname,
        profileImageURL: "",
        schoolId: "1",
        schoolName: "한성대학교",
        attendanceStatus: .presentPending,
        isLocationVerified: false,
        excuseReason: nil
    )
}

// MARK: - displayName

@Suite("ParticipantAttendance — displayName 분기 (도메인 규칙)")
struct ParticipantAttendanceDisplayNameTests {

    @Test(
        "닉네임이 있으면 '닉네임/이름', 비어 있으면 이름만 노출한다",
        arguments: [
            ("길동이", "길동이/홍길동"),
            ("", "홍길동")
        ]
    )
    func displayNameByNicknamePresence(nickname: String, expected: String) {
        let participant = makeParticipant(nickname: nickname)

        #expect(participant.displayName == expected)
    }
}
