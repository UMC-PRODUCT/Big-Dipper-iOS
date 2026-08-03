//
//  MemberContextProviding.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/28/26.
//

import Foundation
import UMCFoundation

/// 멤버 관리 조회에 필요한 현재 사용자 컨텍스트 제공자.
///
/// ``MemberRepositoryProtocol`` 의 멤버 목록 조회가 학교 단위 오프셋 검색이라 `schoolId` 가
/// 있어야 하고, 상벌점 히스토리 열람 권한과 기수 우선순위를 따지려면 `currentMemberId`·
/// `gisuId` 도 필요합니다. Repository 는 이 값들을 여기서 읽어옵니다.
///
/// - Note: ``StudyContextProviding`` 과 같은 이유로 비-`Sendable` 의존성으로 두고,
///   Repository 가 `@unchecked Sendable` 로 감쌉니다. 운영 코드는
///   ``UserDefaultsMemberContextProvider`` 를, 테스트는 가짜 구현을 주입합니다.
protocol MemberContextProviding {

    /// 현재 학교 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var schoolId: String? { get }

    /// 현재 로그인 멤버 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var currentMemberId: String? { get }

    /// 현재(우선) 기수 식별자 — 서버 응답이므로 `String`. 미설정 시 `nil`.
    var gisuId: String? { get }
}

// MARK: - UserDefaultsMemberContextProvider

/// `UserDefaults` 기반 기본 컨텍스트 제공자.
///
/// 키 상수와 저장 형식 해석(신규 `String` 우선, 레거시 `Int` 폴백)은 모두
/// ``UMCFoundation/AppStorageKey`` 의 canonical 헬퍼에 위임합니다. 이 타입은 세 식별자를
/// 컨텍스트 프로토콜 모양으로 묶어 Repository 에 넘기는 역할만 합니다.
struct UserDefaultsMemberContextProvider: MemberContextProviding {

    // MARK: - Property

    private let defaults: UserDefaults

    // MARK: - Init

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: - MemberContextProviding

    var schoolId: String? {
        AppStorageKey.schoolIdString(in: defaults)
    }

    var currentMemberId: String? {
        AppStorageKey.memberIdString(in: defaults)
    }

    var gisuId: String? {
        AppStorageKey.gisuIdString(in: defaults)
    }
}
