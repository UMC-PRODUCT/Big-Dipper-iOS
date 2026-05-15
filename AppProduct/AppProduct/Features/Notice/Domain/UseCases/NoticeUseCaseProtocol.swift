//
//  NoticeUseCaseProtocol.swift
//  AppProduct
//
//  Created by 이예지 on 2/14/26.
//

import Foundation

/// Notice 관련 모든 UseCase를 정의하는 Protocol
protocol NoticeUseCaseProtocol {
    
    // MARK: - 파일 업로드
    
    /// 공지 첨부 이미지를 업로드하고 파일 ID를 반환합니다.
    /// - Parameters:
    ///   - imageData: 업로드할 JPEG 바이너리 데이터
    ///   - fileName: 업로드 파일명 (앨범 원본 이름 기반)
    /// - Returns: 저장된 파일 ID
    func uploadNoticeAttachmentImage(imageData: Data, fileName: String?) async throws -> String
    
    // MARK: - 공지 생성 (POST)
    
    /// 공지사항 완전 생성 (links, images 포함)
    /// - Parameters:
    ///   - title: 공지 제목
    ///   - content: 공지 내용
    ///   - shouldNotify: 알림 발송 여부
    ///   - targetInfo: 수신 대상 정보
    ///   - links: 링크 목록
    ///   - imageIds: 이미지 ID 목록
    ///   - noticeTab: 공지 탭 구분 (CHALLENGER/CENTRAL_MEMBER/SCHOOL_CORE/SCHOOL_PART_LEADER)
    ///   - mustRead: 필독 공지 여부
    /// - Returns: 생성된 공지 상세 정보
    func createNotice(
        title: String,
        content: String,
        shouldNotify: Bool,
        targetInfo: TargetInfoDTO,
        links: [String],
        imageIds: [String],
        noticeTab: String,
        mustRead: Bool
    ) async throws -> NoticeDetail
    
    /// 공지사항 투표 추가 (POST)
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - title: 투표 제목
    ///   - isAnonymous: 익명 투표 여부
    ///   - allowMultipleChoice: 복수 선택 허용 여부
    ///   - startsAt: 투표 시작 시간
    ///   - endsAtExclusive: 투표 종료 시간
    ///   - options: 투표 옵션 목록
    /// - Returns: 생성된 투표 ID 정보
    func addVote(
        noticeId: Int,
        title: String,
        isAnonymous: Bool,
        allowMultipleChoice: Bool,
        startsAt: Date,
        endsAtExclusive: Date,
        options: [String]
    ) async throws -> AddVoteResponseDTO
    
    /// 공지사항 링크 추가 (POST)
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - links: 추가할 링크 목록
    /// - Returns: 업데이트된 공지 정보
    func addLink(noticeId: Int, links: [String]) async throws -> NoticeItemModel
    
    /// 공지사항 이미지 추가 (POST)
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - imageIds: 추가할 이미지 ID 목록
    /// - Returns: 업데이트된 공지 정보
    func addImage(noticeId: Int, imageIds: [String]) async throws -> NoticeItemModel
    
    // MARK: - 공지 읽음 처리 (POST)
    
    /// 공지사항 읽음 처리
    /// - Parameter noticeId: 공지 ID
    func readNotice(noticeId: Int) async throws

    /// 투표 응답(사용자 선택 전송)
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - optionIds: 선택한 옵션 ID 목록
    func submitVoteResponse(noticeId: Int, optionIds: [Int]) async throws

    /// 투표 응답 수정
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - optionIds: 수정할 옵션 ID 목록 (빈 배열 전송 시 응답 취소)
    func updateVoteResponse(noticeId: Int, optionIds: [Int]) async throws
    
    // MARK: - 리마인더 (POST)
    
    /// 리마인더 발송
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - targetIds: 대상 사용자 ID 목록
    func sendReminder(noticeId: Int, targetIds: [Int]) async throws
    
    // MARK: - 공지 수정 (PATCH)
    
    /// 공지사항 수정 (제목, 본문)
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - title: 수정할 제목
    ///   - content: 수정할 본문
    ///   - mustRead: 필독 공지 여부
    /// - Returns: 수정된 공지 상세 정보
    func updateNotice(
        noticeId: Int,
        title: String,
        content: String,
        mustRead: Bool
    ) async throws -> NoticeDetail
    
    /// 공지사항 링크 수정
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - links: 수정할 링크 목록 (전체 교체)
    /// - Returns: 수정된 공지 상세 정보
    func updateLinks(
        noticeId: Int,
        links: [String]
    ) async throws -> NoticeDetail
    
    /// 공지사항 이미지 수정
    /// - Parameters:
    ///   - noticeId: 공지 ID
    ///   - imageIds: 수정할 이미지 ID 목록 (전체 교체)
    /// - Returns: 수정된 공지 상세 정보
    func updateImages(
        noticeId: Int,
        imageIds: [String]
    ) async throws -> NoticeDetail
    
    // MARK: - 공지 조회 (GET)

    /// 공지사항 전체 조회 (페이징)
    /// - Parameter request: 조회 조건 (기수ID, 지부/학교/파트 필터, 페이지 정보)
    ///   - `gisuId`: 조회할 기수 ID
    ///   - `chapterId`: 지부 ID (선택)
    ///   - `schoolId`: 학교 ID (선택)
    ///   - `part`: 파트 타입 (선택)
    ///   - `page`: 페이지 번호 (0부터 시작)
    ///   - `size`: 페이지 크기
    ///   - `sort`: 정렬 조건 (예: ["createdAt,DESC"])
    /// - Returns: 공지사항 목록 페이지 (content: 공지 배열, hasNext: 다음 페이지 존재 여부)
    /// - Note: **[문제 2: 무한로딩]** 이 메서드가 실패하면 NoticeViewModel에서 무한 로딩 발생 가능
    func getAllNotices(request: NoticeListRequestDTO) async throws -> NoticePageDTO<NoticeDTO>

    /// 공지사항 상세 조회
    /// - Parameter noticeId: 조회할 공지 ID
    /// - Returns: 공지 상세 정보 (제목, 내용, 작성자, 링크, 이미지, 투표 정보 포함)
    func getDetailNotice(noticeId: Int) async throws -> NoticeDetail

    /// 공지 열람 통계 조회
    /// - Parameter noticeId: 통계를 조회할 공지 ID
    /// - Returns: 열람 통계 정보 (총 대상자 수, 읽음/안읽음 수)
    func getReadStatics(noticeId: Int) async throws -> NoticeReadStaticsDTO

    /// 공지 열람 현황 상세 조회 (커서 기반 페이징)
    /// - Parameters:
    ///   - noticeId: 조회할 공지 ID
    ///   - cursorId: 커서 ID (다음 페이지 조회 시 사용, 첫 조회는 0)
    ///   - filterType: 필터 타입 ("ORGANIZATION", "SCHOOL" 등)
    ///   - organizationIds: 필터링할 지부 ID 목록
    ///   - status: 읽음 상태 ("READ", "UNREAD", "ALL")
    /// - Returns: 열람 현황 목록 (사용자별 읽음 상태, 다음 커서 ID)
    func getReadStatusList(
        noticeId: Int,
        cursorId: Int,
        filterType: String,
        organizationIds: [Int],
        status: String
    ) async throws -> NoticeReadStatusResponseDTO
    
    /// 공지사항 검색
    /// - Parameters:
    ///   - keyword: 검색 키워드
    ///   - request: 필터 및 페이징 정보
    /// - Returns: 검색 결과 페이지
    func searchNotice(
        keyword: String,
        request: NoticeListRequestDTO
    ) async throws -> NoticePageDTO<NoticeDTO>
    
    // MARK: - 공지 삭제 (DELETE)
    
    /// 공지사항 삭제
    /// - Parameter noticeId: 삭제할 공지 ID
    func deleteNotice(noticeId: Int) async throws

    /// 공지사항에 연결된 투표 삭제
    /// - Parameter noticeId: 공지 ID
    func deleteVote(noticeId: Int) async throws
}
