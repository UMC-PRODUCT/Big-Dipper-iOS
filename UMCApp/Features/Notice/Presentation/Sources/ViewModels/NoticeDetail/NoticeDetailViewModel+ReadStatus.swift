//
//  NoticeDetailViewModel+ReadStatus.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation
import NoticeDomain

extension NoticeDetailViewModel {

    // MARK: - Read Status Actions

    /// 공지 열람 현황 Sheet 표시
    @MainActor
    public func openReadStatusSheet() {
        guard canViewReadStatus else { return }
        showReadStatusSheet = true
        if readStatusState.isIdle {
            Task { await fetchReadStatus() }
        }
    }

    /// 공지 상세 진입 시 통계(read-statics)만 선조회합니다.
    ///
    /// 하단 수신 확인 카드의 숫자/비율을 먼저 안정적으로 노출하고,
    /// 상세 목록(read-status)은 시트 진입 시점에만 로드합니다.
    @MainActor
    public func prefetchReadStaticsIfNeeded(forceReload: Bool = false) async {
        guard canViewReadStatus else { return }
        guard forceReload || !hasPrefetchedReadStatics else { return }
        guard !noticeID.isEmpty && noticeID != "0" else { return }
        if forceReload == false, readStatics != nil { return }

        isReadStaticsLoading = true
        defer { isReadStaticsLoading = false }
        do {
            readStatics = try await noticeUseCase.getReadStatics(noticeId: noticeID)
            hasPrefetchedReadStatics = true
        } catch let error as RepositoryError {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "prefetchReadStaticsIfNeeded"
                )
            )
            // 통계 선조회 실패는 상세 진입을 막지 않으며, 시트 진입 시 재시도할 수 있습니다.
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "prefetchReadStaticsIfNeeded"
                )
            )
            // 통계 선조회 실패는 상세 진입을 막지 않으며, 시트 진입 시 재시도할 수 있습니다.
        }
    }

    /// 읽음 처리 직후 UI를 즉시 반영하기 위해 통계를 낙관적으로 갱신합니다.
    public func applyOptimisticReadStatics() {
        guard let current = readStatics else { return }

        let readCount = Int(current.readCount) ?? 0
        let unreadCount = Int(current.unreadCount) ?? 0
        let totalCount = Int(current.totalCount) ?? max(readCount + unreadCount, 0)

        guard totalCount > 0 else { return }
        guard unreadCount > 0 else { return }
        guard readCount < totalCount else { return }

        let nextReadCount = readCount + 1
        let nextUnreadCount = max(unreadCount - 1, 0)
        let nextReadRate = Double(nextReadCount) / Double(totalCount)

        readStatics = NoticeReadStatics(
            totalCount: String(totalCount),
            readCount: String(nextReadCount),
            unreadCount: String(nextUnreadCount),
            readRate: String(nextReadRate)
        )
    }

    /// 공지 열람 현황 데이터 로드 (통계 + 상세)
    @MainActor
    public func fetchReadStatus(showLoadingState: Bool = true) async {
        guard canViewReadStatus else { return }
        if showLoadingState {
            readStatusState = .loading
        }

        do {
            resetReadStatusPagination()
            if readStatics == nil {
                isReadStaticsLoading = true
                readStatics = try await noticeUseCase.getReadStatics(noticeId: noticeID)
                hasPrefetchedReadStatics = true
                isReadStaticsLoading = false
            }

            let confirmedResponse = try await fetchReadStatusPage(cursorId: 0, status: .confirmed)
            let unconfirmedResponse = try await fetchReadStatusPage(cursorId: 0, status: .unconfirmed)

            let confirmedUsers = confirmedResponse.users
            let unconfirmedUsers = unconfirmedResponse.users
            
            readNextCursor = parseCursor(confirmedResponse.nextCursor)
            unreadNextCursor = parseCursor(unconfirmedResponse.nextCursor)
            hasNextReadPage = confirmedResponse.hasNext
            hasNextUnreadPage = unconfirmedResponse.hasNext

            readStatusState = .loaded(
                NoticeReadStatus(
                    noticeId: noticeID,
                    confirmedUsers: confirmedUsers,
                    unconfirmedUsers: unconfirmedUsers
                )
            )

        } catch let error as RepositoryError {
            isReadStaticsLoading = false
            readStatics = nil
            readStatusState = .failed(.repository(error))
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "fetchReadStatus")
            )
        } catch let error as DomainError {
            isReadStaticsLoading = false
            readStatics = nil
            readStatusState = .failed(.domain(error))
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "fetchReadStatus")
            )
        } catch let error as NetworkError {
            isReadStaticsLoading = false
            readStatics = nil
            readStatusState = .failed(.network(error))
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "fetchReadStatus")
            )
        } catch {
            isReadStaticsLoading = false
            readStatics = nil
            readStatusState = .failed(.unknown(message: error.localizedDescription))
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "fetchReadStatus")
            )
        }
    }

    /// 실패 화면에서 재시도 버튼을 눌렀을 때 호출됩니다.
    @MainActor
    public func retryFetchReadStatus() async {
        guard !isRetryingReadStatus else { return }
        isRetryingReadStatus = true
        defer { isRetryingReadStatus = false }
        await fetchReadStatus(showLoadingState: false)
    }

    /// 현재 선택된 탭 목록에서 특정 아이템이 하단에 도달했는지 확인하고 다음 페이지를 로드합니다.
    ///
    /// 무한 스크롤 방식으로 리스트 끝 근처 아이템이 표시될 때 자동 호출됩니다.
    @MainActor
    public func loadMoreReadStatusIfNeeded(currentItem: ReadStatusUser) async {
        guard var current = readStatusState.value else { return }
        guard !isLoadingMoreReadStatus else { return }

        let currentUsers = selectedReadTab == .confirmed
            ? current.confirmedUsers
            : current.unconfirmedUsers
        guard shouldLoadMore(currentItem: currentItem, in: currentUsers) else { return }

        // 탭별 다음 페이지 존재 여부 및 커서 유효성 확인
        switch selectedReadTab {
        case .confirmed:
            guard hasNextReadPage else { return }
            guard readNextCursor != nil else { return }
        case .unconfirmed:
            guard hasNextUnreadPage else { return }
            guard unreadNextCursor != nil else { return }
        }

        isLoadingMoreReadStatus = true
        defer { isLoadingMoreReadStatus = false }

        do {
            let response = try await fetchReadStatusPage(
                cursorId: selectedReadTab == .confirmed ? (readNextCursor ?? 0) : (unreadNextCursor ?? 0),
                status: selectedReadTab
            )

            let appendedUsers = response.users

            switch selectedReadTab {
            case .confirmed:
                let merged = current.confirmedUsers + appendedUsers
                current = NoticeReadStatus(
                    noticeId: current.noticeId,
                    confirmedUsers: merged,
                    unconfirmedUsers: current.unconfirmedUsers
                )
                readNextCursor = parseCursor(response.nextCursor)
                hasNextReadPage = response.hasNext
            case .unconfirmed:
                let merged = current.unconfirmedUsers + appendedUsers
                current = NoticeReadStatus(
                    noticeId: current.noticeId,
                    confirmedUsers: current.confirmedUsers,
                    unconfirmedUsers: merged
                )
                unreadNextCursor = parseCursor(response.nextCursor)
                hasNextUnreadPage = response.hasNext
            }

            readStatusState = .loaded(current)
        } catch let error as RepositoryError {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "loadMoreReadStatusIfNeeded")
            )
            // 페이징 실패는 기존 데이터를 유지합니다.
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "Notice", action: "loadMoreReadStatusIfNeeded")
            )
            // 페이징 실패는 기존 데이터를 유지합니다.
        }
    }

    /// 탭 전환
    public func switchReadTab(to tab: ReadStatusTab) {
        selectedReadTab = tab
    }

    // MARK: - Read Status Helper

    /// 읽음/안읽음 상세 목록 페이지를 조회합니다.
    public func fetchReadStatusPage(
        cursorId: Int,
        status: ReadStatusTab
    ) async throws -> NoticeReadStatusPage {
        try await noticeUseCase.getReadStatusList(
            noticeId: noticeID,
            cursorId: String(cursorId),
            filterType: "ALL",
            organizationIds: [],
            status: status == .confirmed ? "READ" : "UNREAD"
        )
    }

    /// 커서 페이지네이션 상태를 초기화합니다.
    public func resetReadStatusPagination() {
        readNextCursor = nil
        unreadNextCursor = nil
        hasNextReadPage = false
        hasNextUnreadPage = false
        isLoadingMoreReadStatus = false
    }

    /// 무한 스크롤 트리거 여부를 판단합니다.
    public func shouldLoadMore(currentItem: ReadStatusUser, in users: [ReadStatusUser]) -> Bool {
        guard let currentIndex = users.firstIndex(where: { $0.id == currentItem.id }) else {
            return false
        }
        let thresholdIndex = max(users.count - 3, 0)
        return currentIndex >= thresholdIndex
    }

    /// 문자열 커서를 Int로 변환합니다.
    public func parseCursor(_ value: String) -> Int? {
        guard !value.isEmpty else { return nil }
        return Int(value)
    }
}
