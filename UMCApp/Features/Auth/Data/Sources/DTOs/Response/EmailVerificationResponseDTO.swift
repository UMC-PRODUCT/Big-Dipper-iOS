//
//  EmailVerificationResponseDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

import UMCFoundation

/// 이메일 인증 발송/재전송 API 응답 DTO
///
/// `emailVerificationId`는 서버가 String("51")로 내려주지만 Int로 흔들릴 수 있어
/// flexible String 디코딩(절대 규칙 #2/#3)을 적용한다.
public struct EmailVerificationResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    public let emailVerificationId: String

    private enum CodingKeys: String, CodingKey {
        case emailVerificationId
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        emailVerificationId = container.decodeFlexibleStringOrEmpty(forKey: .emailVerificationId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(emailVerificationId, forKey: .emailVerificationId)
    }
}
