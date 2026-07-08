//
//  MyPageRouterTest.swift
//  MyPageData
//
//  Created by One on 5/10/26.
//

import Foundation
import Testing
import Moya
import CoreNetwork
import MyPageDomain
@testable import MyPageData

@Suite("MyPageRouter")
struct MyPageRouterTests {

    // MARK: - getMyProfile case

    @Suite("getMyProfile")
    struct GetMyProfileTests {

        @Test("path는 /api/v1/member/me 이다")
        func path() {
            let router = MyPageRouter.getMyProfile
            #expect(router.path == "/api/v1/member/me")
        }

        @Test("method는 .get이다")
        func method() {
            let router = MyPageRouter.getMyProfile
            #expect(router.method == .get)
        }

        @Test("task는 .requestPlain이다")
        func task() {
            let router = MyPageRouter.getMyProfile

            guard case .requestPlain = router.task else {
                Issue.record("Expected .requestPlain, got \(router.task)")
                return
            }
        }
    }

    // MARK: - getTerms case

    @Suite("getTerms")
    struct GetTermsTests {

        @Test("path는 /api/v1/terms/type/{termsType} 형식이다",
              arguments: ["PRIVACY", "SERVICE", "MARKETING"])
        func path(termsType: String) {
            let router = MyPageRouter.getTerms(termsType: termsType)
            #expect(router.path == "/api/v1/terms/type/\(termsType)")
        }

        @Test("method는 .get이다")
        func method() {
            let router = MyPageRouter.getTerms(termsType: "PRIVACY")
            #expect(router.method == .get)
        }

        @Test("task는 .requestPlain이다")
        func task() {
            let router = MyPageRouter.getTerms(termsType: "PRIVACY")

            guard case .requestPlain = router.task else {
                Issue.record("Expected .requestPlain, got \(router.task)")
                return
            }
        }
    }

    // MARK: - BaseTargetType extension defaults

    @Suite("BaseTargetType 기본 구현")
    struct BaseTargetTypeDefaultsTests {

        // NOTE: baseURL/headers는 NetworkConfig → Info.plist의 BASE_URL을 읽는데,
        //       UMCApp Secret 인프라(Secrets.xcconfig + Project.swift infoPlist 주입)가
        //       아직 미구축 상태라 테스트 번들에서 fatalError가 발생합니다.
        //       후속 Secret 인프라 PR에서 인프라 구축 후 .disabled를 제거하세요.
        @Test(
            "baseURL은 NetworkConfig.baseURL을 사용한다",
            .disabled("UMCApp Secret 인프라 구축 후 활성화")
        )
        func baseURL() {
            let router = MyPageRouter.getTerms(termsType: "PRIVACY")
            #expect(router.baseURL == NetworkConfig.baseURL)
        }

        @Test(
            "headers는 NetworkConfig.defaultHeaders를 사용한다",
            .disabled("UMCApp Secret 인프라 구축 후 활성화")
        )
        func headers() {
            let router = MyPageRouter.getTerms(termsType: "PRIVACY")
            #expect(router.headers == NetworkConfig.defaultHeaders)
        }

        @Test("validationType은 .successCodes다")
        func validationType() {
            let router = MyPageRouter.getTerms(termsType: "PRIVACY")

            guard case .successCodes = router.validationType else {
                Issue.record("Expected .successCodes, got \(router.validationType)")
                return
            }
        }
    }
}

// MARK: - 이식 케이스: path / method

/// `refac/803`에서 이식된 케이스(멤버·챌린저 프로필, 회원 수정·탈퇴, 활동 게시글)의
/// path·method 계약을 검증합니다.
/// (`getMyProfile`/`getTerms`는 위 `MyPageRouterTests` 스위트에서 별도 검증)
@Suite("MyPageRouter — 이식 케이스 path/method 계약")
struct MyPageRouterMigratedPathMethodTests {

    @Test("getMemberProfile — memberId가 path에 보간되고 method는 .get")
    func getMemberProfile() {
        let router = MyPageRouter.getMemberProfile(memberId: 7)
        #expect(router.path == "/api/v1/member/profile/7")
        #expect(router.method == .get)
    }

    @Test("getChallengerProfile — challengerId가 path에 보간되고 method는 .get")
    func getChallengerProfile() {
        let router = MyPageRouter.getChallengerProfile(challengerId: 3)
        #expect(router.path == "/api/v1/challenger/3")
        #expect(router.method == .get)
    }

    @Test("addChallengerRecord — path는 /api/v1/challenger-record/member, method는 .post")
    func addChallengerRecord() {
        let router = MyPageRouter.addChallengerRecord(code: "ABC123")
        #expect(router.path == "/api/v1/challenger-record/member")
        #expect(router.method == .post)
    }

    @Test("patchMember — path는 /api/v1/member, method는 .patch")
    func patchMember() {
        let router = MyPageRouter.patchMember(
            request: UpdateMemberProfileImageRequestDTO(profileImageId: "img-1")
        )
        #expect(router.path == "/api/v1/member")
        #expect(router.method == .patch)
    }

    @Test("patchMemberProfileLinks — path는 /api/v1/member/profile/links, method는 .patch")
    func patchMemberProfileLinks() {
        let router = MyPageRouter.patchMemberProfileLinks(
            request: UpdateMemberProfileLinksRequestDTO(links: [])
        )
        #expect(router.path == "/api/v1/member/profile/links")
        #expect(router.method == .patch)
    }

    @Test("deleteMember — path는 /api/v1/member, method는 .delete")
    func deleteMember() {
        let router = MyPageRouter.deleteMember
        #expect(router.path == "/api/v1/member")
        #expect(router.method == .delete)
    }

    @Test("활동 게시글 3종 — 각자 고유 path에 method는 .get")
    func postListPathsAndMethod() {
        let query = MyPagePostListQueryDTO(query: MyPagePostListQuery())
        #expect(MyPageRouter.getMyPosts(query: query).path == "/api/v1/posts/my")
        #expect(MyPageRouter.getCommentedPosts(query: query).path == "/api/v1/posts/commented")
        #expect(MyPageRouter.getScrappedPosts(query: query).path == "/api/v1/posts/scrapped")
        #expect(MyPageRouter.getMyPosts(query: query).method == .get)
        #expect(MyPageRouter.getCommentedPosts(query: query).method == .get)
        #expect(MyPageRouter.getScrappedPosts(query: query).method == .get)
    }

    @Test("patchMember와 deleteMember는 path가 같고 method로만 구분된다")
    func patchAndDeleteShareSamePath() {
        let patch = MyPageRouter.patchMember(
            request: UpdateMemberProfileImageRequestDTO(profileImageId: "x")
        )
        let delete = MyPageRouter.deleteMember
        #expect(patch.path == delete.path)      // 둘 다 /api/v1/member
        #expect(patch.method == .patch)
        #expect(delete.method == .delete)
    }
}

// MARK: - 이식 케이스: task 형태

@Suite("MyPageRouter — 이식 케이스 task 형태 계약")
struct MyPageRouterMigratedTaskTests {

    @Test("조회·삭제 계열(getMemberProfile/getChallengerProfile/deleteMember) — task는 .requestPlain")
    func plainTasks() {
        #expect(isRequestPlain(MyPageRouter.getMemberProfile(memberId: 7).task))
        #expect(isRequestPlain(MyPageRouter.getChallengerProfile(challengerId: 3).task))
        #expect(isRequestPlain(MyPageRouter.deleteMember.task))
    }

    @Test("본문 전송 계열(addChallengerRecord/patchMember/patchMemberProfileLinks) — task는 .requestJSONEncodable")
    func jsonEncodableTasks() {
        #expect(isRequestJSONEncodable(MyPageRouter.addChallengerRecord(code: "ABC").task))
        #expect(isRequestJSONEncodable(
            MyPageRouter.patchMember(
                request: UpdateMemberProfileImageRequestDTO(profileImageId: "x")
            ).task
        ))
        #expect(isRequestJSONEncodable(
            MyPageRouter.patchMemberProfileLinks(
                request: UpdateMemberProfileLinksRequestDTO(links: [])
            ).task
        ))
    }

    @Test("활동 게시글 3종 — task는 .requestParameters(URLEncoding.queryString) + page/size 포함")
    func postListTasksAreQueryParameters() {
        let query = MyPagePostListQueryDTO(
            query: MyPagePostListQuery(page: 1, size: 10, sort: [])
        )
        let routers = [
            MyPageRouter.getMyPosts(query: query),
            MyPageRouter.getCommentedPosts(query: query),
            MyPageRouter.getScrappedPosts(query: query),
        ]
        for router in routers {
            guard case let .requestParameters(parameters, encoding) = router.task else {
                Issue.record("Expected .requestParameters, got \(router.task)")
                continue
            }
            #expect(encoding is URLEncoding)
            #expect(parameters["page"] as? Int == 1)
            #expect(parameters["size"] as? Int == 10)
        }
    }
}

// MARK: - 요청 DTO / 쿼리 인코딩 계약

@Suite("MyPageRouter — 요청 DTO/쿼리 인코딩 계약")
struct MyPageRouterEncodingTests {

    @Test("AddChallengerRecordRequestDTO — { code } 단일 키로 인코딩")
    func addChallengerRecordDTOEncoding() throws {
        let json = try encodeToJSON(AddChallengerRecordRequestDTO(code: "INVITE-42"))
        #expect(json["code"] as? String == "INVITE-42")
        #expect(json.keys.count == 1)
    }

    @Test("UpdateMemberProfileImageRequestDTO — { profileImageId } 단일 키로 인코딩")
    func updateProfileImageDTOEncoding() throws {
        let json = try encodeToJSON(UpdateMemberProfileImageRequestDTO(profileImageId: "file-9"))
        #expect(json["profileImageId"] as? String == "file-9")
        #expect(json.keys.count == 1)
    }

    @Test("UpdateMemberProfileLinkRequestDTO — { type, link } 로 인코딩")
    func updateProfileLinkItemDTOEncoding() throws {
        let json = try encodeToJSON(
            UpdateMemberProfileLinkRequestDTO(type: "GITHUB", link: "https://github.com/x")
        )
        #expect(json["type"] as? String == "GITHUB")
        #expect(json["link"] as? String == "https://github.com/x")
        #expect(json.keys.count == 2)
    }

    @Test("UpdateMemberProfileLinksRequestDTO — { links: [...] } 배열 래핑으로 인코딩")
    func updateProfileLinksDTOEncoding() throws {
        let dto = UpdateMemberProfileLinksRequestDTO(links: [
            UpdateMemberProfileLinkRequestDTO(type: "GITHUB", link: "https://gh"),
            UpdateMemberProfileLinkRequestDTO(type: "BLOG", link: "https://blog"),
        ])
        let json = try encodeToJSON(dto)
        let links = try #require(json["links"] as? [[String: Any]])
        #expect(json.keys.count == 1)
        #expect(links.count == 2)
        #expect(links.first?["type"] as? String == "GITHUB")
        #expect(links.first?["link"] as? String == "https://gh")
    }

    @Test("MyPagePostListQueryDTO.toParameters — sort가 비면 page/size 2키만 포함")
    func postListQueryParametersWithoutSort() {
        let dto = MyPagePostListQueryDTO(
            query: MyPagePostListQuery(page: 2, size: 20, sort: [])
        )
        let params = dto.toParameters
        #expect(params["page"] as? Int == 2)
        #expect(params["size"] as? Int == 20)
        #expect(params["sort"] == nil)
        #expect(params.keys.count == 2)
    }

    @Test("MyPagePostListQueryDTO.toParameters — sort가 있으면 sort 배열 포함 3키")
    func postListQueryParametersWithSort() {
        let dto = MyPagePostListQueryDTO(
            query: MyPagePostListQuery(page: 0, size: 10, sort: ["createdAt,DESC"])
        )
        let params = dto.toParameters
        #expect(params["page"] as? Int == 0)
        #expect(params["size"] as? Int == 10)
        #expect(params["sort"] as? [String] == ["createdAt,DESC"])
        #expect(params.keys.count == 3)
    }
}

// MARK: - Test Helpers

private func isRequestPlain(_ task: Moya.Task) -> Bool {
    if case .requestPlain = task { return true }
    return false
}

private func isRequestJSONEncodable(_ task: Moya.Task) -> Bool {
    if case .requestJSONEncodable = task { return true }
    return false
}

private func encodeToJSON(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let object = try JSONSerialization.jsonObject(with: data)
    return try #require(object as? [String: Any])
}
