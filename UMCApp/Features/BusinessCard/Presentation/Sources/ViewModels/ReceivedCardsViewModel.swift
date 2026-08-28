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
                await self?.load()
            }
        }
    }

    private let fetchReceivedCards: FetchReceivedCardsUseCaseProtocol

    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Init

    public init(fetchReceivedCards: FetchReceivedCardsUseCaseProtocol) {
        self.fetchReceivedCards = fetchReceivedCards
    }

    // MARK: - Computed Property

    /// 공백뿐인 검색어는 전체 조회로 되돌린다 — 그대로 넘기면 아무것도 안 걸려
    /// 사용자 눈에는 명함이 통째로 사라진 것처럼 보인다.
    private var trimmedQuery: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Function

    public func load() async {
        cards = .loading
        do {
            cards = .loaded(try await fetchReceivedCards.execute(query: trimmedQuery))
        } catch let error as AppError {
            cards = .failed(error)
        } catch {
            cards = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 이미 목록이 떠 있을 때 조용히 다시 맞춘다 — 상세에서 삭제·메모 편집을 하고
    /// 돌아온 경우다. `.loading` 을 거치지 않는다: 스켈레톤이 한 번 깜빡이고 스크롤이
    /// 맨 위로 튀는데, 화면에 이미 답이 떠 있는 상황에서는 그게 더 손해다.
    /// 실패해도 조용히 둔다 — 지금 보이는 목록이 최신이 아닐 뿐 틀리지 않았다.
    public func refresh() async {
        guard let refreshed = try? await fetchReceivedCards.execute(query: trimmedQuery) else {
            return
        }
        cards = .loaded(refreshed)
    }
}
