//
//  NoticeEditorTargetUseCaseProtocol.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation

/// 공지 에디터 타겟(지부/학교) 조회 UseCase 인터페이스
public protocol NoticeEditorTargetUseCaseProtocol {
    /// 전체 지부 목록을 조회합니다.
    func fetchAllBranches() async throws -> [NoticeTargetOption]
    /// 특정 기수에 속한 지부 목록을 조회합니다.
    func fetchBranches(gisuId: String) async throws -> [NoticeTargetOption]
    /// 지부 ID로 지부명을 조회합니다.
    func fetchBranchName(chapterId: String) async throws -> String
    /// 전체 학교 목록을 조회합니다.
    func fetchAllSchools() async throws -> [NoticeTargetOption]
    /// 특정 기수에 속한 학교 목록을 조회합니다.
    func fetchSchools(gisuId: String) async throws -> [NoticeTargetOption]
    /// 특정 지부(챕터)에 속한 학교 목록을 조회합니다.
    /// - Parameters:
    ///   - chapterId: 지부 ID
    ///   - gisuId: 기수 ID
    func fetchSchools(inChapterId chapterId: String, gisuId: String) async throws -> [NoticeTargetOption]
}
