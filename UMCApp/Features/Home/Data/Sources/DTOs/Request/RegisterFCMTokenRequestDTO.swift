//
//  RegisterFCMTokenRequestDTO.swift
//  HomeData
//

import Foundation

/// FCM 설치 등록 요청 DTO (`POST /api/v1/notifications/fcm/installations`).
///
/// `memberId`는 서버가 JWT principal에서 뽑으므로 바디에 넣지 않습니다.
struct RegisterFCMTokenRequestDTO: Encodable, Sendable, Equatable {
    /// 기기별 설치 식별자. 필수 · 공백 불가 · 최대 100자.
    let installationId: String
    /// FCM 등록 토큰. 필수 · 공백 불가 · 최대 4096자.
    let fcmToken: String
    /// 플랫폼 이름. 선택 · 최대 30자.
    let platform: String
    /// 앱 마케팅 버전. 선택 · 최대 50자 (빈 문자열 허용).
    let appVersion: String
}
