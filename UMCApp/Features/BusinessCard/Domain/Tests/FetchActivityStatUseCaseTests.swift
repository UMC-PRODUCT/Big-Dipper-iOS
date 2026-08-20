//
//  FetchActivityStatUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

@Suite("FetchActivityStatUseCase — 병렬 조합과 소스별 0 폴백")
struct FetchActivityStatUseCaseTests {

    @Test("네 소스가 전부 성공하면 각 값이 String으로 담긴다")
    func combinesAllSources() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success(3)
        stat.bookmarkCountResult = .success("7")
        stat.activityCountResult = .success(2)
        let received = MockReceivedCardRepository()
        received.countResult = .success(12)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: received
        )

        let result = await sut.execute()

        #expect(result == ActivityStat(
            receivedCardCount: "12", studyCount: "3", activityCount: "2", bookmarkCount: "7"
        ))
    }

    @Test("한 소스가 실패해도 그 값만 0이고 나머지는 유지된다 (MP-F07 우측 값 일관)")
    func failedSourceFallsBackToZero() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .failure(MockError.notStubbed) // 스터디만 실패
        stat.bookmarkCountResult = .success("7")               // 서버 원본 String
        stat.activityCountResult = .success(2)
        let received = MockReceivedCardRepository()
        received.countResult = .success(12)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: received
        )

        let result = await sut.execute()

        #expect(result.studyCount == "0")
        #expect(result.bookmarkCount == "7")
        #expect(result.receivedCardCount == "12")
    }

    @Test("스크랩 카운트가 빈 문자열이면 0으로 채운다")
    func blankBookmarkCountFallsBackToZero() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success(0)
        stat.bookmarkCountResult = .success("  ")
        stat.activityCountResult = .success(0)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: MockReceivedCardRepository()
        )

        let result = await sut.execute()

        #expect(result.bookmarkCount == "0")
    }

    @Test("서버가 준 비정상 문자열도 변환 없이 통과시킨다 (절대규칙 #2)")
    func passesServerValueThrough() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success(0)
        stat.bookmarkCountResult = .success("1,024")
        stat.activityCountResult = .success(0)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: MockReceivedCardRepository()
        )

        let result = await sut.execute()

        #expect(result.bookmarkCount == "1,024")
    }
}
