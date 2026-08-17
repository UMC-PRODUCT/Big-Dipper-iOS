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
    static let feature = "BusinessCard"
}

/// 명함첩 목록·검색·삭제 (MP-F05).
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
    private let deleteReceivedCard: DeleteReceivedCardUseCaseProtocol
    private let errorHandler: ErrorHandler

    @ObservationIgnored private var reloadTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        fetchReceivedCards: FetchReceivedCardsUseCaseProtocol,
        deleteReceivedCard: DeleteReceivedCardUseCaseProtocol,
        errorHandler: ErrorHandler
    ) {
        self.fetchReceivedCards = fetchReceivedCards
        self.deleteReceivedCard = deleteReceivedCard
        self.errorHandler = errorHandler
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

    /// 실패하면 목록을 건드리지 않는다. 지워진 줄 알고 화면을 뜬 사용자가 다음 진입에서
    /// 되살아난 명함을 보는 쪽이, 삭제가 안 됐다고 지금 듣는 것보다 나쁘다.
    public func delete(id: String) async {
        do {
            try await deleteReceivedCard.execute(id: id)
            // 재조회 대신 그 자리에서 뺀다 — 다시 긁으면 스크롤이 튀고 저장소 왕복이
            // 한 번 더 붙는다. 목록 순서는 저장소가 정하므로 제거만으로 어긋나지 않는다.
            if let loaded = cards.value {
                cards = .loaded(loaded.filter { $0.id != id })
            }
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: Constants.feature, action: "deleteReceivedCard")
            )
        }
    }
}
