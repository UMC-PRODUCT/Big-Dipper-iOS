//
//  AppStorageKey.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

/// @AppStorage 접근 키
///
/// UserDefaults 사용을 줄이고 `@AppStorage`로 관리합니다.
/// 로그인/승인 완료 시 `SyncProfileStorageUseCase`에서 저장됩니다.
public enum AppStorageKey {

    // MARK: - System

    /// FCM 푸시 토큰
    public static let userFCMToken: String = "UserFCMToken"
    /// 서버에 마지막으로 등록한 FCM 토큰
    public static let uploadedFCMToken: String = "UploadedFCMToken"
    /// 서버에 마지막으로 등록한 멤버 ID
    public static let uploadedFCMMemberId: String = "UploadedFCMMemberId"
    /// 최근 검색 장소 목록
    public static let recentSearchPlaces: String = "recentSearchPlaces"
    /// OAuth 연동된 소셜 provider 목록(JSON 문자열 배열)
    public static let connectedSocialProviders: String = "connectedSocialProviders"
    /// 자동 로그인 허용 여부 (승인/등록 완료 사용자만 true)
    public static let canAutoLogin: String = "canAutoLogin"

    // MARK: - Profile (최신 기수 기준)

    /// 서버 기수 식별 ID
    public static let gisuId: String = "gisuId"
    /// 멤버 고유 ID
    public static let memberId: String = "memberId"
    /// 챌린저 ID (패널티 API 파라미터)
    public static let challengerId: String = "challengerId"
    /// 학교 ID
    public static let schoolId: String = "schoolId"
    /// 학교 이름
    public static let schoolName: String = "schoolName"
    /// 지부 ID
    public static let chapterId: String = "chapterId"
    /// 지부 이름
    public static let chapterName: String = "chapterName"
    /// 담당 파트 (`UMCPartType.apiValue` 문자열, 예: "IOS")
    public static let responsiblePart: String = "responsiblePart"
    /// 멤버 역할 (`ManagementTeam.rawValue` 문자열)
    public static let memberRole: String = "memberRole"
    /// 사용자가 보유한 전체 역할 목록 (`[ManagementTeam.rawValue]`)
    public static let memberRoles: String = "memberRoles"
    /// 기수별 소속 조직 정보(JSON 문자열)
    public static let generationOrganizations: String = "generationOrganizations"
    /// 소속 조직 타입 (`OrganizationType.rawValue` 문자열)
    public static let organizationType: String = "organizationType"
    /// 소속 조직 ID (`organizationType`에 따라 지부/학교 ID)
    public static let organizationId: String = "organizationId"
    /// 공지 탭에서 현재 선택한 기수 ID (공지 작성 진입 시 사용)
    public static let noticeSelectedGisuId: String = "noticeSelectedGisuId"

    // MARK: - Session Lifecycle

    /// 로그인 세션 단위로 보관되는 키 목록입니다.
    ///
    /// 로그아웃 시 일괄 삭제되어, 다른 계정으로 재로그인할 때 이전 계정의
    /// 프로필/역할/조직 정보가 잔존하지 않도록 합니다.
    ///
    /// 디바이스 단위 정보(FCM 토큰, 최근 검색어 등)는 포함하지 않습니다.
    public nonisolated static let sessionScopedKeys: [String] = [
        canAutoLogin,
        gisuId,
        memberId,
        challengerId,
        schoolId,
        schoolName,
        chapterId,
        chapterName,
        responsiblePart,
        memberRole,
        memberRoles,
        generationOrganizations,
        organizationType,
        organizationId,
        noticeSelectedGisuId
    ]

    /// 세션 단위 AppStorage 값을 일괄 삭제합니다.
    ///
    /// 로그아웃 / 회원 탈퇴 / 세션 만료 처리 시 호출해야 합니다.
    /// `UserDefaults` 접근은 thread-safe하므로 actor 격리 없이 호출 가능합니다.
    public nonisolated static func clearSessionScopedValues(
        in defaults: UserDefaults = .standard
    ) {
        sessionScopedKeys.forEach { defaults.removeObject(forKey: $0) }
    }
}

// MARK: - Member ID 어댑터

extension AppStorageKey {

    /// 멤버 ID를 `String`으로 조회합니다.
    ///
    /// 신규 저장값(`String`)을 우선 사용하고, 레거시 `Int` 저장값을 발견하면
    /// 문자열로 변환해 반환합니다. 둘 다 없으면 `nil`을 반환합니다.
    public static func memberIdString(in defaults: UserDefaults = .standard) -> String? {
        if let value = defaults.string(forKey: memberId), !value.isEmpty {
            return value
        }
        let legacyInt = defaults.integer(forKey: memberId)
        return legacyInt > 0 ? String(legacyInt) : nil
    }

    /// 멤버 ID를 레거시 `Int` 형태로 조회합니다.
    ///
    /// 신규 `String` 저장값을 `Int`로 변환해 우선 반환하고, 변환에 실패하거나
    /// `String` 값이 없으면 레거시 `Int` 저장값으로 폴백합니다.
    /// `Int` 식별자를 기대하는 out-of-scope 호출자(Activity / Notice / AppDelegate)가
    /// 점진적 마이그레이션 동안 사용합니다.
    public static func legacyMemberIdInt(in defaults: UserDefaults = .standard) -> Int {
        if let stringValue = defaults.string(forKey: memberId),
           let intValue = Int(stringValue) {
            return intValue
        }
        return defaults.integer(forKey: memberId)
    }
}
