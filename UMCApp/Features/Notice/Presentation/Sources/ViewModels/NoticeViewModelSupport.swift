//
//  NoticeViewModelSupport.swift
//  NoticeData
//
//  Created by 이예지 on 5/27/26.
//

import Foundation
import NoticeDomain

// MARK: - NoticeUserContext
/// 공지 탭 라벨/필터에 필요한 사용자 컨텍스트입니다.
public struct NoticeUserContext {
    public let schoolName: String
    public let branchName: String
    public let part: NoticePart?

    public static let empty = NoticeUserContext(
        schoolName: "학교",
        chapterName: "지부",
        responsiblePart: nil
    )

    public init(
        schoolName: String,
        chapterName: String,
        responsiblePart: String?
    ) {
        let normalizedSchool = schoolName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedChapter = chapterName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.schoolName = normalizedSchool.isEmpty ? "학교" : normalizedSchool
        self.branchName = normalizedChapter.isEmpty ? "지부" : normalizedChapter
        self.part = NoticePart(apiValue: responsiblePart ?? "")
    }

}

// MARK: - NoticeGenerationTargetState
/// 선택 기수별 지부/학교 필터 옵션 캐시입니다.
public struct NoticeGenerationTargetState: Equatable {
    public var branches: [NoticeTargetOption] = []
    public var schools: [NoticeTargetOption] = []
}

// MARK: - NoticePagingState
/// 공지 목록/검색 공통 페이징 상태입니다.
struct NoticePagingState {
    private(set) var currentPage: Int = 0
    private(set) var hasNextPage: Bool = false
    private(set) var isLoadingMore: Bool = false

    mutating func begin(page: Int) -> Bool {
        if page == 0 {
            isLoadingMore = false
            return true
        }
        guard hasNextPage, !isLoadingMore else { return false }
        isLoadingMore = true
        return true
    }

    mutating func applySuccess(page: Int, hasNextPage: Bool) {
        currentPage = page
        self.hasNextPage = hasNextPage
        isLoadingMore = false
    }

    mutating func applyFailure() {
        isLoadingMore = false
    }

    mutating func reset() {
        currentPage = 0
        hasNextPage = false
        isLoadingMore = false
    }

    var nextPage: Int {
        currentPage + 1
    }
}
