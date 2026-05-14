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
@testable import MyPageData

@Suite("MyPageRouter")
struct MyPageRouterTests {

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
