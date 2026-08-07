//
//  FetchStudyMembersUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/8/26.
//

import Foundation

/// 스터디 그룹 멤버 조회 도메인 진입점
///
/// 단일 스터디 그룹의 멘토(파트장) + 스터디원 전체 목록을 조회하는 **멤버 조회 전용** UseCase.
/// 9차 운영진 스터디 관리 / 챌린저 스터디 화면이 구성원 표시에 의존합니다.
///
/// - Note: 그룹 생성·수정·삭제, 멤버·멘토 추가·제거 등 CRUD 는 `StudyRepositoryProtocol` 이
///   직접 노출하므로 본 UseCase 의 책임에서 제외합니다 (facade 비대화 방지). 일정 생성과
///   그룹-일정 연결은 ``RegisterStudyScheduleUseCaseProtocol`` 이 맡습니다.
public protocol FetchStudyMembersUseCaseProtocol {

    /// 단일 스터디 그룹의 멘토 + 스터디원 전체 목록을 반환합니다.
    ///
    /// `StudyRepositoryProtocol/fetchStudyGroupDetail(groupId:)` 의 `mentors` 와 `members`
    /// 를 멘토 우선 순서로 병합해 반환합니다.
    ///
    /// - Parameter groupId: 스터디 그룹 식별자 (서버 응답 String ID)
    /// - Returns: 멘토 뒤에 스터디원이 이어지는 `[StudyGroupMember]`. 빈 그룹이면 빈 배열.
    func fetchStudyGroupMembers(groupId: String) async throws -> [StudyGroupMember]
}
