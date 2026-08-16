//
//  PeerCardRepositoryTests.swift
//  BusinessCardDataTests
//
//  Created by One on 8/16/26.
//

import Foundation
import Testing
import Moya
import CoreDomain
import CoreNetwork
import UMCFoundation
@testable import BusinessCardData

/// QR 딥링크가 서버 공개 프로필로 상대 명함을 복원하는 경로의 계약.
///
/// 이 경로는 **조용히 무너질 수 있다** — 응답에 `roles`·`challengerRecords`가 없으면
/// 변환이 에러를 던지지 않고 `part = .admin`, `generation = "0"`인 명함을 만든다.
/// 서버 마스킹 정책이 바뀌면 잘못된 명함이 명함첩에 그대로 저장되므로, 여기서 그 동작을
/// 계약으로 고정해 변화를 감지한다.
@Suite("PeerCardRepository — 딥링크 명함 복원")
struct PeerCardRepositoryTests {

    private final class StubRequesting: BusinessCardNetworkRequesting, @unchecked Sendable {
        var responsesByPath: [String: Data] = [:]
        private(set) var requestedPaths: [String] = []

        func request<T: TargetType>(_ target: T) async throws -> Response {
            requestedPaths.append(target.path)
            return Response(statusCode: 200, data: responsesByPath[target.path] ?? Data())
        }
    }

    private static let profilePath = "/api/v1/member/profile/42"

    // MARK: - Router 계약

    @Test("라우터는 GET /api/v1/member/profile/{memberId} · 본문 없음")
    func routerContract() throws {
        let router = BusinessCardRouter.getMemberProfile(memberId: "42")

        #expect(router.path == Self.profilePath)
        #expect(router.method == .get)
        guard case .requestPlain = router.task else {
            Issue.record("requestPlain이 아님"); return
        }
    }

    // MARK: - 정상 응답

    @Test("공개 프로필 전체 필드 — 이름·파트·기수·학교·외부 링크가 명함으로 복원된다")
    func restoresCardFromPublicProfile() async throws {
        let stub = StubRequesting()
        stub.responsesByPath[Self.profilePath] = Data("""
        {"success":true,"code":"200","message":"ok","result":{
          "id":"42","name":"정의찬","nickname":"제옹","email":null,
          "schoolId":"7","schoolName":"홍익대학교",
          "profileImageLink":"https://cdn.umc.it.kr/a.png",
          "profile":{"id":"9","linkedIn":"https://linkedin.com/in/one",
                     "instagram":null,"github":"https://github.com/one",
                     "blog":"https://blog.one","personal":null},
          "status":"ACTIVE",
          "roles":[],
          "challengerRecords":[
            {"challengerId":"100","memberId":"42","gisu":"12","gisuId":"3",
             "chapterId":"1","chapterName":"서울","part":"IOS",
             "schoolId":"7","schoolName":"홍익대학교","name":"정의찬","nickname":"제옹",
             "email":null,"profileImageLink":null,"status":"ACTIVE","challengerPoints":[]}
          ]}}
        """.utf8)
        let sut = PeerCardRepository(networkRequesting: stub)

        let card = try await sut.fetchCard(memberId: "42")

        #expect(card.memberId == "42")
        #expect(card.name == "정의찬")
        #expect(card.nickname == "제옹")
        #expect(card.university == "홍익대학교")
        #expect(card.generation == "12")
        #expect(card.part == .front(type: .ios))
        #expect(card.github == "https://github.com/one")
        #expect(card.linkedIn == "https://linkedin.com/in/one")
        #expect(card.blog == "https://blog.one")
        #expect(card.avatarURL == "https://cdn.umc.it.kr/a.png")
        // 서버가 타인 응답에서 마스킹하는 값 — 명함 뒷면이 이걸 쓰지 않는 근거다.
        #expect(card.email == nil)
    }

    @Test("래핑 없는 raw 응답도 흡수한다")
    func absorbsRawResponse() async throws {
        let stub = StubRequesting()
        stub.responsesByPath[Self.profilePath] = Data("""
        {"id":"42","name":"정의찬","nickname":"제옹","email":null,
         "schoolId":"7","schoolName":"홍익대학교","profileImageLink":null,
         "profile":null,"status":"ACTIVE","roles":[],
         "challengerRecords":[
           {"challengerId":"100","memberId":"42","gisu":"12","gisuId":"3",
            "chapterId":null,"chapterName":null,"part":"IOS",
            "schoolId":"7","schoolName":"홍익대학교","name":null,"nickname":null,
            "email":null,"profileImageLink":null,"status":"ACTIVE","challengerPoints":[]}
         ]}
        """.utf8)
        let sut = PeerCardRepository(networkRequesting: stub)

        let card = try await sut.fetchCard(memberId: "42")

        #expect(card.generation == "12")
        #expect(card.part == .front(type: .ios))
    }

    // MARK: - 무너지는 방식을 고정한다

    @Test("roles·challengerRecords가 비면 에러 없이 part=admin·generation=0으로 복원된다")
    func silentlyDegradesWhenRecordsMissing() async throws {
        let stub = StubRequesting()
        stub.responsesByPath[Self.profilePath] = Data("""
        {"success":true,"code":"200","message":"ok","result":{
          "id":"42","name":"정의찬","nickname":"제옹","email":null,
          "schoolId":"7","schoolName":"홍익대학교","profileImageLink":null,
          "profile":null,"status":"ACTIVE","roles":[],"challengerRecords":[]}}
        """.utf8)
        let sut = PeerCardRepository(networkRequesting: stub)

        let card = try await sut.fetchCard(memberId: "42")

        // 던지지 않는다는 것 자체가 이 경로의 위험이다. 값이 바뀌면 서버 응답이 달라졌다는 신호.
        #expect(card.part == .admin)
        #expect(card.generation == "0")
        #expect(card.name == "정의찬")
    }

    @Test("빈 memberId는 네트워크를 타지 않고 즉시 실패한다")
    func rejectsEmptyMemberId() async throws {
        let stub = StubRequesting()
        let sut = PeerCardRepository(networkRequesting: stub)

        await #expect(throws: AppError.self) {
            _ = try await sut.fetchCard(memberId: "")
        }
        #expect(stub.requestedPaths.isEmpty)
    }
}
