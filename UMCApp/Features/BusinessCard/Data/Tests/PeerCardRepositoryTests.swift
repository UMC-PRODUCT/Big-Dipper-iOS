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
/// 이 경로는 **조용히 무너졌었다** — 응답에 `roles`·`challengerRecords`가 없으면 변환이
/// 에러를 던지지 않고 `part = .admin`, `generation = "0"`인 명함을 만들어 그대로 저장했다.
/// 지금은 실패로 돌린다 (#1223). 서버 마스킹 정책이 바뀌면 사용자가 안내를 보고, 잘못된
/// 명함이 명함첩에 남지 않는다.
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

    // MARK: - 빈 프로필은 실패다 (#1223)

    @Test("roles·challengerRecords가 비면 「운영진·0기」 폴백 대신 실패한다")
    func failsWhenRecordsMissing() async throws {
        let stub = StubRequesting()
        stub.responsesByPath[Self.profilePath] = Data("""
        {"success":true,"code":"200","message":"ok","result":{
          "id":"42","name":"정의찬","nickname":"제옹","email":null,
          "schoolId":"7","schoolName":"홍익대학교","profileImageLink":null,
          "profile":null,"status":"ACTIVE","roles":[],"challengerRecords":[]}}
        """.utf8)
        let sut = PeerCardRepository(networkRequesting: stub)

        // 사용자가 보는 문장까지 고정한다 — 조용한 성공이 아니라 안내가 떠야 한다.
        await #expect(throws: AppError.domain(.custom(message: "명함 정보를 불러오지 못했어요."))) {
            _ = try await sut.fetchCard(memberId: "42")
        }
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
