//
//  FetchActivityStatUseCaseTests.swift
//  BusinessCardDomainTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
@testable import BusinessCardDomain

@Suite("FetchActivityStatUseCase — 병렬 조합과 소스별 실패 구분")
struct FetchActivityStatUseCaseTests {

    @Test("네 소스가 전부 성공하면 각 값이 String으로 담긴다")
    func combinesAllSources() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success("3")
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

    /// 예전에는 실패한 소스도 `"0"` 으로 채워서, 통신이 끊긴 화면이 「스터디 0건」이라고
    /// 단언했다. 실패는 `nil` 로 남아야 화면이 "-"를 그린다 (#1222).
    @Test("한 소스가 실패하면 그 값만 nil이고 나머지는 유지된다")
    func failedSourceBecomesNil() async {
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

        #expect(result.studyCount == nil)
        #expect(result.bookmarkCount == "7")
        #expect(result.receivedCardCount == "12")
    }

    /// 「0개다」와 「못 세었다」가 같은 화면 문자열이 되면 안 된다.
    @Test("0건 성공과 조회 실패는 다른 값이다")
    func zeroDiffersFromFailure() async {
        let succeeded = MockActivityStatRepository()
        succeeded.studyCountResult = .success("0")
        succeeded.bookmarkCountResult = .success("0")
        succeeded.activityCountResult = .success(0)
        let failed = MockActivityStatRepository()  // 전 소스 미스텁 = 실패
        let received = MockReceivedCardRepository()
        received.countResult = .success(0)

        let zero = await FetchActivityStatUseCase(
            statRepository: succeeded, receivedCardRepository: received
        ).execute()
        let unknown = await FetchActivityStatUseCase(
            statRepository: failed, receivedCardRepository: MockReceivedCardRepository()
        ).execute()

        #expect(zero.studyCount == "0")
        #expect(unknown.studyCount == nil)
        #expect(zero != unknown)
    }

    /// 잘림 표기는 저장소가 붙인다 — UseCase는 문자열을 건드리지 않고 통과시킨다.
    @Test("잘림 표기(\"50+\")를 변형 없이 통과시킨다")
    func passesTruncationMarkerThrough() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success("50+")
        stat.bookmarkCountResult = .success("0")
        stat.activityCountResult = .success(0)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: MockReceivedCardRepository()
        )

        #expect(await sut.execute().studyCount == "50+")
    }

    @Test("스크랩 카운트가 빈 문자열이면 못 세운 것으로 본다")
    func blankBookmarkCountBecomesNil() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success("0")
        stat.bookmarkCountResult = .success("  ")
        stat.activityCountResult = .success(0)
        let sut = FetchActivityStatUseCase(
            statRepository: stat,
            receivedCardRepository: MockReceivedCardRepository()
        )

        let result = await sut.execute()

        #expect(result.bookmarkCount == nil)
    }

    @Test("서버가 준 비정상 문자열도 변환 없이 통과시킨다 (절대규칙 #2)")
    func passesServerValueThrough() async {
        let stat = MockActivityStatRepository()
        stat.studyCountResult = .success("0")
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
