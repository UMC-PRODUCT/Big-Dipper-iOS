//
//  NoticeRequestFactory.swift
//  AppProduct
//
//  Created by euijjang97 on 2/16/26.
//

import Foundation

// MARK: - NoticeRequestFactory
/// 공지 목록/검색 요청 DTO를 생성합니다.
enum NoticeRequestFactory {
    /// 메인필터에 따라 적절한 NoticeListRequestDTO를 생성합니다.
    ///
    /// - Parameters:
    ///   - gisuId: 조회할 기수 ID
    ///   - page: 페이지 번호
    ///   - selectedMainFilter: 현재 선택된 메인필터
    ///   - chapterId: 사용자 지부 ID
    ///   - schoolId: 사용자 학교 ID
    /// - Returns: API 요청용 DTO
    static func make(
        gisuId: Int,
        page: Int,
        selectedMainFilter: NoticeMainFilterType,
        chapterId: Int,
        schoolId: Int,
        pageSize: Int,
        sort: [String]
    ) -> NoticeListRequestDTO {
        let myChapterId: Int? = chapterId > 0 ? chapterId : nil
        let mySchoolId: Int? = schoolId > 0 ? schoolId : nil

        let requestChapterId: Int?
        let requestSchoolId: Int?
        let requestPart: UMCPartType?

        switch selectedMainFilter {
        case .all, .central:
            // iOS-01 (UMC 공지): gisuId only
            requestChapterId = nil
            requestSchoolId = nil
            requestPart = nil
        case .branch:
            // iOS-03 (지부 필터): gisuId + chapterId
            requestChapterId = myChapterId
            requestSchoolId = nil
            requestPart = nil
        case .school:
            // iOS-02 (학교 필터): gisuId + schoolId
            requestChapterId = nil
            requestSchoolId = mySchoolId
            requestPart = nil
        case .part(let filterPart):
            // iOS-04 (파트 필터): gisuId + part
            requestChapterId = nil
            requestSchoolId = nil
            requestPart = filterPart.umcPartType
        }

        return NoticeListRequestDTO(
            gisuId: gisuId,
            chapterId: requestChapterId,
            schoolId: requestSchoolId,
            part: requestPart,
            noticeTab: "CHALLENGER",
            page: page,
            size: pageSize,
            sort: sort
        )
    }
}
