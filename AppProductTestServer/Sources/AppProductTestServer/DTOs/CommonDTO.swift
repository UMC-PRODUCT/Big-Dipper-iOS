//
//  File.swift
//  AppProductTestServer
//
//  Created by euijjang97 on 1/10/26.
//


import Vapor

/// UMC 백엔드의 `ApiResponse<T>` 계약을 흉내내는 공통 응답 래퍼입니다.
///
/// JSON 직렬화 시 `isSuccess` 프로퍼티는 `success` 키로 인코딩되어
/// 클라이언트(CoreNetwork `APIResponse<T>`) 와 형태가 일치합니다.
struct CommonDTO<T: Content>: Content {
    let isSuccess: Bool
    let code: String?
    let message: String?
    let result: T?

    init(isSuccess: Bool = true, code: String? = "SUCCESS", message: String? = "성공", result: T? = nil) {
        self.isSuccess = isSuccess
        self.code = code
        self.message = message
        self.result = result
    }

    static func success(_ result: T, code: String = "SUCCESS", message: String = "성공") -> CommonDTO<T> {
        CommonDTO(isSuccess: true, code: code, message: message, result: result)
    }

    static func failure(code: String, message: String) -> CommonDTO<T> {
        CommonDTO(isSuccess: false, code: code, message: message, result: nil)
    }

    enum CodingKeys: String, CodingKey {
        case isSuccess = "success"
        case code
        case message
        case result
    }
}

struct EmptyResult: Content {}
