//
//  RegisterFCMTokenRequestDTO.swift
//  HomeData
//

import Foundation

/// FCM 토큰 등록 요청 DTO.
struct RegisterFCMTokenRequestDTO: Encodable, Sendable, Equatable {
    let fcmToken: String
}
