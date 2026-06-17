//
//  MemberManagementItem.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/17/26.
//

import Foundation
import UMCFoundation

// MARK: - GenerationPointSummary

/// 기수별 상벌점 요약 데이터
public struct GenerationPointSummary: Equatable, Identifiable {
    public var id: Int { gisu }

    /// 기수 (예: 9)
    public let gisu: Int

    /// 누적 상점
    public let reward: Double

    /// 누적 벌점
    public let penalty: Double

    public init(gisu: Int, reward: Double, penalty: Double) {
        self.gisu = gisu
        self.reward = reward
        self.penalty = penalty
    }
}

// MARK: - MemberManagementItem

/// 멤버 관리 리스트에서 사용되는 데이터 모델입니다.
///
/// 멤버 카드 뷰와 멤버 상세 시트에서 공통으로 사용됩니다.
public struct MemberManagementItem: Identifiable, Equatable {

    // MARK: - Property

    /// 고유 식별자 (클라이언트 생성)
    public let id: UUID

    /// 멤버 고유 식별자 (서버 응답)
    public let memberID: String?

    /// 챌린저 고유 식별자 (서버 응답)
    public let challengerID: String?

    /// 프로필 이미지 리소스
    public let profile: String?

    /// 멤버 이름
    public let name: String

    /// 멤버 닉네임
    public let nickname: String

    /// 기수 정보 (예: "9기")
    public let generation: String

    /// 소속 학교
    public let school: String

    /// 포지션 정보
    public let position: String

    /// 파트 정보 (iOS, Web 등)
    public let part: UMCPartType

    /// 현재 누적 벌점
    public let penalty: Double

    /// 현재 누적 상점
    public let rewardPoints: Double

    /// 뱃지 표시 여부
    public let badge: Bool

    /// 운영진 직책 정보 (회장, 부회장 등)
    public let managementTeam: ManagementTeam

    /// 출석/활동 기록 목록
    public let attendanceRecords: [MemberAttendanceRecord]

    /// 상벌점 히스토리
    public let penaltyHistory: [OperatorMemberPenaltyHistory]

    /// 상벌점 히스토리 열람 가능 여부
    public let canViewPenaltyHistory: Bool

    /// 기수별 상벌점 요약 목록
    public let generationPoints: [GenerationPointSummary]

    // MARK: - Initializer

    public init(
        id: UUID = .init(),
        memberID: String? = nil,
        challengerID: String? = nil,
        profile: String?,
        name: String,
        nickname: String,
        generation: String,
        school: String,
        position: String,
        part: UMCPartType,
        penalty: Double,
        rewardPoints: Double = 0,
        badge: Bool,
        managementTeam: ManagementTeam,
        attendanceRecords: [MemberAttendanceRecord],
        penaltyHistory: [OperatorMemberPenaltyHistory],
        canViewPenaltyHistory: Bool = true,
        generationPoints: [GenerationPointSummary] = []
    ) {
        self.id = id
        self.memberID = memberID
        self.challengerID = challengerID
        self.profile = profile
        self.name = name
        self.nickname = nickname
        self.generation = generation
        self.school = school
        self.position = position
        self.part = part
        self.penalty = penalty
        self.rewardPoints = rewardPoints
        self.badge = badge
        self.managementTeam = managementTeam
        self.attendanceRecords = attendanceRecords
        self.penaltyHistory = penaltyHistory
        self.canViewPenaltyHistory = canViewPenaltyHistory
        self.generationPoints = generationPoints
    }
}
