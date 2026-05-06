//
//  NoticeRepositoryProtocol.swift
//  AppProduct
//
//  Created by 이예지 on 2/14/26.
//

import Foundation

/// 공지사항 데이터 접근 계층 인터페이스
///
/// 공지사항 CRUD, 열람 현황, 투표, 리마인더 등 데이터 소스 접근을 추상화합니다.
protocol NoticeRepositoryProtocol {
    
    // MARK: - 공지 생성
    /// 공지사항 전체 생성
    func createNotice(
        body: PostNoticeRequestDTO,
        // TODO: 투표
        links: [String],
        imageIds: [String]
    ) async throws -> NoticeDetail
    
    /// 공지사항 글 생성
    func postNotice(body: PostNoticeRequestDTO) async throws -> NoticeItemModel
    
    /// 공지사항 투표 추가
    func addVote(
        noticeId: Int,
        body: AddVoteRequestDTO
    ) async throws -> AddVoteResponseDTO
    
    /// 공지사항 링크 추가
    func addLink(noticeId: Int, links: [String]) async throws -> NoticeItemModel
    
    /// 공지사항 이미지 추가
    func addImage(noticeId: Int, imageIds: [String]) async throws -> NoticeItemModel
    
    /// 공지사항 리마인더 발송
    func sendReminder(noticeId: Int, targetIds: [Int]) async throws
    
    /// 공지사항 읽음 처리
    func readNotice(noticeId: Int) async throws

    /// 투표 응답(사용자 선택 전송)
    func submitVoteResponse(noticeId: Int, optionIds: [Int]) async throws

    /// 투표 응답 수정
    func updateVoteResponse(noticeId: Int, optionIds: [Int]) async throws
    
    // MARK: - 공지 수정
    /// 공지사항 수정 (제목, 본문)
    func updateNotice(
        noticeId: Int,
        body: UpdateNoticeRequestDTO
    ) async throws -> NoticeDetail
    
    /// 공지사항 링크 수정
    func updateLinks(
        noticeId: Int,
        links: [String]
    ) async throws -> NoticeDetail
    
    /// 공지사항 이미지 수정
    func updateImages(
        noticeId: Int,
        imageIds: [String]
    ) async throws -> NoticeDetail
    
    // MARK: - 공지 조회
    /// 공지사항 전체 조회
    func getAllNotices(request: NoticeListRequestDTO) async throws -> NoticePageDTO<NoticeDTO>
    
    /// 공지사항 상세 조회
    func getDetailNotice(noticeId: Int) async throws -> NoticeDetail
    
    /// 공지 열람 통계 조회
    func getReadStatics(noticeId: Int) async throws -> NoticeReadStaticsDTO
    
    /// 공지 열람 현황 상세 조회
    func getReadStatusList(
        noticeId: Int,
        cursorId: Int,
        filterType: String,
        organizationIds: [Int],
        status: String
    ) async throws -> NoticeReadStatusResponseDTO
    
    /// 공지사항 검색
    func searchNotice(
        keyword: String,
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO>
    
    // MARK: - 공지 삭제
    /// 공지사항 삭제
    func deleteNotice(noticeId: Int) async throws

    /// 공지사항에 연결된 투표 삭제
    func deleteVote(noticeId: Int) async throws
}
