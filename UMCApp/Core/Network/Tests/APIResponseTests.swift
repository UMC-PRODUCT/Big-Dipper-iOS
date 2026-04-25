//
//  APIResponseTests.swift
//  CoreNetworkTests
//
//  Created by euijjang97 on 4/25/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import CoreNetwork

@Suite("APIResponse")
struct APIResponseTests {

    // MARK: - Decoding

    @Test("서버 응답 JSON을 success/code/message/result 키로 디코딩한다")
    func decodesServerJSONKeys() throws {
        let json = """
        {
            "success": true,
            "code": "200",
            "message": "성공",
            "result": { "id": 42, "name": "정의재" }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(APIResponse<UserDTO>.self, from: json)

        #expect(response.isSuccess)
        #expect(response.code == "200")
        #expect(response.message == "성공")
        #expect(response.result?.id == 42)
        #expect(response.result?.name == "정의재")
    }

    @Test("실패 응답은 isSuccess=false, result=nil로 디코딩된다")
    func decodesFailureResponse() throws {
        let json = """
        {
            "success": false,
            "code": "AUTH001",
            "message": "인증에 실패했습니다",
            "result": null
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(APIResponse<UserDTO>.self, from: json)

        #expect(!response.isSuccess)
        #expect(response.code == "AUTH001")
        #expect(response.message == "인증에 실패했습니다")
        #expect(response.result == nil)
    }

    // MARK: - unwrap()

    @Test("unwrap()은 성공 응답일 때 result를 반환한다")
    func unwrapReturnsResultOnSuccess() throws {
        let response = APIResponse(
            isSuccess: true,
            code: "200",
            message: "성공",
            result: UserDTO(id: 1, name: "test")
        )

        let result = try response.unwrap()

        #expect(result.id == 1)
        #expect(result.name == "test")
    }

    @Test("unwrap()은 isSuccess=false이면 RepositoryError.serverError를 throw한다")
    func unwrapThrowsServerErrorOnFailure() {
        let response = APIResponse<UserDTO>(
            isSuccess: false,
            code: "AUTH001",
            message: "인증 실패",
            result: nil
        )

        #expect(throws: RepositoryError.serverError(code: "AUTH001", message: "인증 실패")) {
            _ = try response.unwrap()
        }
    }

    @Test("unwrap()은 result==nil이지만 EmptyResult 타입이면 빈 값을 반환한다")
    func unwrapReturnsEmptyResultWhenNilResultButEmptyResultType() throws {
        let response = APIResponse<EmptyResult>(
            isSuccess: true,
            code: "200",
            message: "성공",
            result: nil
        )

        let result = try response.unwrap()

        #expect(result == EmptyResult())
    }

    @Test("unwrap()은 result==nil이고 EmptyResult가 아니면 serverError를 throw한다")
    func unwrapThrowsWhenNilResultAndNotEmptyResultType() {
        let response = APIResponse<UserDTO>(
            isSuccess: true,
            code: nil,
            message: nil,
            result: nil
        )

        #expect(throws: RepositoryError.serverError(code: nil, message: nil)) {
            _ = try response.unwrap()
        }
    }

    // MARK: - validateSuccess()

    @Test("validateSuccess()는 isSuccess=true이면 throw하지 않는다")
    func validateSuccessDoesNotThrow() throws {
        let response = APIResponse<EmptyResult>(
            isSuccess: true,
            code: "200",
            message: nil,
            result: nil
        )

        try response.validateSuccess()
    }

    @Test("validateSuccess()는 isSuccess=false이면 RepositoryError.serverError를 throw한다")
    func validateSuccessThrowsOnFailure() {
        let response = APIResponse<EmptyResult>(
            isSuccess: false,
            code: "ERR",
            message: "fail",
            result: nil
        )

        #expect(throws: RepositoryError.serverError(code: "ERR", message: "fail")) {
            try response.validateSuccess()
        }
    }

    // MARK: - errorMessage / errorCode

    @Test("errorMessage 기본값과 errorCode 기본값을 반환한다")
    func defaultErrorFields() {
        let response = APIResponse<EmptyResult>(
            isSuccess: false,
            code: nil,
            message: nil,
            result: nil
        )

        #expect(response.errorMessage == "알 수 없는 오류가 발생했습니다")
        #expect(response.errorCode == "UNKNOWN")
    }

    @Test("errorMessage와 errorCode는 서버 값을 우선 사용한다")
    func errorFieldsPreferServerValues() {
        let response = APIResponse<EmptyResult>(
            isSuccess: false,
            code: "AUTH001",
            message: "토큰 만료",
            result: nil
        )

        #expect(response.errorMessage == "토큰 만료")
        #expect(response.errorCode == "AUTH001")
    }
}

// MARK: - Test Fixtures

private struct UserDTO: Codable, Equatable {
    let id: Int
    let name: String
}
