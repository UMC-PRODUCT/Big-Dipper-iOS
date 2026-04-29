//
//  ScheduleRegistrationData.swift
//  AppProduct
//
//  Created by euijjang97 on 1/22/26.
//

import Foundation

/// 일정 생성 시작 및 종료 날짜 범위
/// 일정 생성 시작 및 종료 날짜 범위
struct DateRange: Sendable {
    /// 시작 날짜 및 시간
    var startDate: Date
    /// 종료 날짜 및 시간
    var endDate: Date
}

/// 장소 검색 정보
///
/// 사용자가 선택한 장소의 이름, 주소, 좌표 정보를 포함합니다.
struct PlaceSearchInfo: Equatable, Sendable {
    /// 장소 이름
    var name: String
    /// 상세 주소
    var address: String
    /// 위경도 좌표
    var coordinate: Coordinate
}

/// 챌린저(참여자) 정보 모델
///
/// 일정에 참여하는 멤버의 정보를 나타냅니다.
/// 검색 및 선택 기능에서 사용됩니다.
struct ChallengerInfo: Identifiable, Equatable, Hashable {
    /// 고유 식별자
    var id: UUID = .init()
    
    /// member ID (서버 응답 String 기준)
    let memberId: String

    /// challenger ID (챌린저 엔티티 식별용)
    let challengerId: Int
    
    /// 기수 (예: 11기)
    let gen: Int
    
    /// 실명
    let name: String
    
    /// 닉네임 (활동명)
    let nickname: String
    
    /// 소속 학교명
    let schoolName: String
    
    /// 프로필 이미지 URL (Optional)
    let profileImage: String?
    
    /// UMC 파트 및 부서 정보 (iOS, Web, Server 등)
    let part: UMCPartType

    /// 검색/선택 UI에서 사용하는 안정적인 행 식별 키
    ///
    /// 동일 memberId라도 기수/파트가 다르면 별도 항목으로 취급합니다.
    var selectionKey: String {
        "\(memberId)|\(gen)|\(part.apiValue)"
    }

    init(
        id: UUID = .init(),
        memberId: String,
        challengerId: Int? = nil,
        gen: Int,
        name: String,
        nickname: String,
        schoolName: String,
        profileImage: String?,
        part: UMCPartType
    ) {
        self.id = id
        self.memberId = memberId
        self.challengerId = challengerId ?? (Int(memberId) ?? 0)
        self.gen = gen
        self.name = name
        self.nickname = nickname
        self.schoolName = schoolName
        self.profileImage = profileImage
        self.part = part
    }
}
