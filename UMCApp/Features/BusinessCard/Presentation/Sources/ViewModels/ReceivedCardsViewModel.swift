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

    static let deleteTitle = "명함을 삭제할까요?"
    static let deleteConfirm = "삭제"
    static let deleteCancel = "취소"

    static func deleteMessage(name: String) -> String {
        "\(name) 님의 명함을 명함첩에서 지웁니다. 다시 교환하기 전까지 되돌릴 수 없어요."
    }
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

    /// 삭제 확인 다이얼로그. `.alertPrompt(item:)` 로 화면에 연결한다.
    public var alertPrompt: AlertPrompt?

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

    /// - Parameter showsLoading: `.loading` 을 거칠지. 당겨서 새로고침은 `false` 다 —
    ///   목록을 스켈레톤으로 갈아 끼우면 사용자가 잡고 있는 화면이 통째로 사라지고
    ///   시스템 새로고침 인디케이터와 이중으로 보인다.
    public func load(showsLoading: Bool = true) async {
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

    /// 당겨서 새로고침 (#1230). 실패 후 화면을 나갔다 다시 들어와야 재시도되던 것을 없앤다.
    public func refresh() async {
        await load(showsLoading: false)
    }

    /// 명함첩은 서버 사본이 없다 — 지우면 다시 교환하기 전까지 복구할 수 없어서
    /// 그리드에서 바로 지우지 않고 확인을 한 번 받는다.
    public func requestDelete(_ card: ReceivedCard) {
        alertPrompt = AlertPrompt(
            title: Constants.deleteTitle,
            message: Constants.deleteMessage(name: card.profile.name),
            positiveBtnTitle: Constants.deleteConfirm,
            positiveBtnAction: { [weak self] in
                Task { await self?.delete(id: card.id) }
            },
            negativeBtnTitle: Constants.deleteCancel,
            isPositiveBtnDestructive: true
        )
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
