//
//  NoticeEditorTargetRepository.swift
//  NoticeData
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import CoreNetwork
import NoticeDomain
import Moya

/// 공지 에디터 타겟(지부/학교) 조회 Repository 구현체
public struct NoticeEditorTargetRepository: NoticeEditorTargetRepositoryProtocol {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - NoticeEditorTargetRepositoryProtocol

    /// 전체 지부 목록 조회 API를 호출하고 지부명 배열을 반환합니다.
    public func fetchAllBranches() async throws -> [NoticeTargetOption] {
        let response = try await adapter.request(NoticeEditorTargetRouter.getAllChapters)
        let apiResponse = try decoder.decode(
            APIResponse<ChapterListResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().chapters.map {
            NoticeTargetOption(id: $0.id, name: $0.name)
        }
    }

    /// 기수별 지부/학교 응답에서 지부 목록만 추출합니다.
    public func fetchBranches(gisuId: String) async throws -> [NoticeTargetOption] {
        try await fetchChaptersWithSchools(gisuId: gisuId).map {
            NoticeTargetOption(id: $0.chapterId, name: $0.chapterName)
        }
    }

    /// 지부 ID로 지부명을 조회합니다.
    public func fetchBranchName(chapterId: String) async throws -> String {
        let response = try await adapter.request(NoticeEditorTargetRouter.getChapter(chapterId: chapterId))
        let apiResponse = try decoder.decode(
            APIResponse<ChapterDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().name
    }

    /// 전체 학교 목록 조회 API를 호출하고 학교명 배열을 반환합니다.
    public func fetchAllSchools() async throws -> [NoticeTargetOption] {
        let response = try await adapter.requestWithoutAuth(NoticeEditorTargetRouter.getAllSchools)
        let apiResponse = try decoder.decode(
            APIResponse<NoticeEditorSchoolListResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().schools.map {
            NoticeTargetOption(id: $0.schoolId, name: $0.schoolName)
        }
    }

    /// 기수별 지부/학교 응답을 평탄화해 학교 목록을 반환합니다.
    public func fetchSchools(gisuId: String) async throws -> [NoticeTargetOption] {
        let chapters = try await fetchChaptersWithSchools(gisuId: gisuId)
        let schools = chapters.flatMap(\.schools)
        let uniqueSchools = Dictionary(grouping: schools, by: \.schoolId).compactMap { _, grouped in
            grouped.first
        }

        return uniqueSchools.map {
            NoticeTargetOption(id: $0.schoolId, name: $0.schoolName)
        }
        .sorted { $0.name < $1.name }
    }

    /// 기수별 지부/학교 조회 API 결과에서 내 지부의 학교만 추출합니다.
    public func fetchSchools(inChapterId chapterId: String, gisuId: String) async throws -> [NoticeTargetOption] {
        let chapters = try await fetchChaptersWithSchools(gisuId: gisuId)
        let targetSchools = chapters
            .first(where: { $0.chapterId == chapterId })?
            .schools ?? []
        return targetSchools.map {
            NoticeTargetOption(id: $0.schoolId, name: $0.schoolName)
        }
    }

    // MARK: - Private

    /// 기수별 지부/학교 응답을 공통 디코딩합니다.
    private func fetchChaptersWithSchools(gisuId: String) async throws -> [ChapterWithSchoolsDTO] {
        let response = try await adapter.request(
            NoticeEditorTargetRouter.getChaptersWithSchools(gisuId: gisuId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<ChapterWithSchoolsResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().chapters
    }
}
