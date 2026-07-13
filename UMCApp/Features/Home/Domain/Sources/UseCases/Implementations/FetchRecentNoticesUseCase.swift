//
//  FetchRecentNoticesUseCase.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/11/26.
//

import NoticeDomain

/// 홈 화면 최근 공지 조회 UseCase 구현체
///
/// 최신 기수의 공지사항을 최신순으로 조회해 상위 5건만 반환한다.
/// 목록/상세 조회 파이프라인은 `NoticeDomain`/`NoticeData`에 이미 이식되어 있어
/// 그대로 재사용하고, "최근 5건" 조합 로직만 홈 전용으로 추가한다.
public final class FetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol {

    // MARK: - Property

    private let repository: NoticeRepositoryProtocol

    // MARK: - Init

    public init(repository: NoticeRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(gisuId: String) async throws -> [NoticeItemModel] {
        let request = NoticeListRequest(
            gisuId: gisuId,
            chapterId: nil,
            schoolId: nil,
            part: nil,
            page: Constants.firstPage,
            size: Constants.recentNoticeCount,
            sort: Constants.sortByCreatedAtDescending
        )
        let page = try await repository.getAllNotices(request: request)
        return Array(page.items.prefix(Constants.recentNoticeCount))
    }
}

private enum Constants {
    static let firstPage = 0
    static let recentNoticeCount = 5
    static let sortByCreatedAtDescending = ["createdAt,DESC"]
}
