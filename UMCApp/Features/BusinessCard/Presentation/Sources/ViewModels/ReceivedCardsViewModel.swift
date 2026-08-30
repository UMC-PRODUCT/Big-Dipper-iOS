//
//  ReceivedCardsViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import Foundation
import BusinessCardDomain
import UMCFoundation

// MARK: - Constants

private enum Constants {
    /// 한 글자마다 저장소를 긁지 않으려는 최소 간격 (커뮤니티 스레드 검색과 동일).
    static let searchDebounce: Duration = .milliseconds(300)
}

/// 명함첩 목록·검색 (MP-F05). 삭제는 상세 화면이 맡는다 (#1227).
///
/// - Important: `@MainActor` 로 못 박는다. 명함첩 저장소는 SwiftData `mainContext` 를
///   들고 있어서 다른 큐에서 만지면 간헐적으로 멈춘다.
@MainActor
@Observable
public final class ReceivedCardsViewModel {

    // MARK: - Property

    public private(set) var cards: Loadable<[ReceivedCard]> = .idle

    /// 검색 필드 바인딩. 값이 바뀌면 디바운스 뒤 스스로 다시 조회한다.
    public var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            reloadTask?.cancel()
            reloadTask = Task { [weak self] in
                try? await Task.sleep(for: Constants.searchDebounce)
                guard !Task.isCancelled else { return }
                // 검색은 캐시만 다시 읽는다. 여기서 동기화를 부르면 글자마다 전량 왕복이
                // 나간다.
                await self?.reloadFromCache(showsLoading: true)
            }
        }
    }

    private let fetchReceivedCards: FetchReceivedCardsUseCaseProtocol
    private let syncReceivedCards: SyncReceivedCardsUseCaseProtocol

    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        fetchReceivedCards: FetchReceivedCardsUseCaseProtocol,
        syncReceivedCards: SyncReceivedCardsUseCaseProtocol
    ) {
        self.fetchReceivedCards = fetchReceivedCards
        self.syncReceivedCards = syncReceivedCards
    }

    // MARK: - Computed Property

    /// 공백뿐인 검색어는 전체 조회로 되돌린다 — 그대로 넘기면 아무것도 안 걸려
    /// 사용자 눈에는 명함이 통째로 사라진 것처럼 보인다.
    private var trimmedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Function

    /// - Parameter showsLoading: `.loading` 을 거칠지. 당겨서 새로고침은 `false` 다 —
    ///   목록을 스켈레톤으로 갈아 끼우면 사용자가 잡고 있는 화면이 통째로 사라지고
    ///   시스템 새로고침 인디케이터와 이중으로 보인다.
    public func load(showsLoading: Bool = true) async {
        await reloadFromCache(showsLoading: showsLoading)
        // 동기화 실패는 삼킨다 — 서버를 못 만나도 캐시로 목록은 떠야 하고, 이미 답이 떠
        // 있는 화면을 네트워크 오류로 덮으면 사용자가 할 수 있는 일이 없다.
        guard (try? await syncReceivedCards.execute()) != nil else { return }
        await reloadFromCache(showsLoading: false)
    }

    /// 서버를 거치지 않고 로컬 캐시만 다시 읽는다.
    private func reloadFromCache(showsLoading: Bool) async {
        if showsLoading {
            cards = .loading
        }

        do {
            cards = .loaded(try await fetchReceivedCards.execute(query: trimmedQuery))
        } catch let error as BusinessCardError {
            cards = .failed(error.asAppError)
        } catch {
            // `.unknown` 으로 뭉개면 Repository·Network 에러가 전부 「일시적인 오류」가
            // 되어 재시도 가능 여부까지 잃는다. `AppError.from` 이 타입별로 정규화한다.
            cards = .failed(AppError.from(error))
        }
    }

    /// 이미 목록이 떠 있을 때 조용히 다시 맞춘다 — 상세에서 삭제·메모 편집을 하고
    /// 돌아온 경우다. `.loading` 을 거치지 않는다: 스켈레톤이 한 번 깜빡이고 스크롤이
    /// 맨 위로 튀는데, 화면에 이미 답이 떠 있는 상황에서는 그게 더 손해다.
    /// 실패해도 조용히 둔다 — 지금 보이는 목록이 최신이 아닐 뿐 틀리지 않았다.
    ///
    /// - Note: 당겨서 새로고침은 이 경로가 아니라 `load(showsLoading: false)` 다.
    ///   사용자가 직접 요청한 갱신이라 실패를 삼키면 제스처가 먹통으로 읽힌다.
    public func refresh() async {
        guard let refreshed = try? await fetchReceivedCards.execute(query: trimmedQuery) else {
            return
        }
        cards = .loaded(refreshed)
    }
}
