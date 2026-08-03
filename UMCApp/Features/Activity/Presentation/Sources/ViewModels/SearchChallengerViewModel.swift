//
//  SearchChallengerViewModel.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDomain
import Foundation
import UMCFoundation

/// 챌린저 검색 화면의 상태를 관리하는 ViewModel
///
/// 키워드 검색·커서 페이지네이션·선택 상태 유지·CSV 일괄 선택을 담당합니다.
/// 조회는 `SearchChallengersUseCaseProtocol` 에만 의존합니다(Repository 직접 의존 금지).
///
/// - Note: 동시성 가드는 **요청 토큰(latest-wins)** 입니다. 검색은 키워드가 바뀔 때마다
///   재요청되므로 형제 ViewModel 의 재진입 가드(`if state.isLoading { return }`)를 그대로
///   쓰면 **나중 키워드가 무시**됩니다. 그래서 검색 경로는 토큰으로 stale 응답만 버리고,
///   중복 요청 차단이 필요한 페이지네이션에만 `isFetchingNextPage` 가드를 둡니다.
///   페이지 응답도 같은 토큰을 검증해 키워드 전환 중 도착한 페이지가 다른 키워드의 목록에
///   섞이지 않게 합니다.
@MainActor
@Observable
final class SearchChallengerViewModel {

    // MARK: - Constants

    private enum Constants {
        /// 한 번에 조회할 챌린저 수 (서버 상한 50)
        static let pageSize = 50
    }

    // MARK: - Property

    private let searchChallengersUseCase: SearchChallengersUseCaseProtocol

    /// 현재 검색 결과 목록
    ///
    /// 상태(`loadState`)에서 파생합니다. 목록을 따로 저장하면 로드 상태와 어긋날 수 있어
    /// 형제 `MemberListViewModel` 과 같이 단일 출처로 둡니다.
    var allChallengers: [ChallengerInfo] { loadState.value ?? [] }

    /// 현재 선택된 챌린저들의 행 식별 키 목록
    var selectedKeys: Set<String> = []

    /// 선택된 챌린저 정보를 별도 보관 (검색 결과가 바뀌어도 선택 유지)
    var selectedChallengersMap: [String: ChallengerInfo] = [:]

    /// CSV 파일 가져오기 문서 피커 표시 여부
    var showCSVImporter: Bool = false

    /// 알림창 상태 (CSV 결과 통보, 에러 안내)
    var alertPrompt: AlertPrompt?

    /// 검색 결과 로드 상태
    private(set) var loadState: Loadable<[ChallengerInfo]> = .idle

    /// 다음 페이지 존재 여부
    private(set) var hasNext: Bool = false

    /// 다음 페이지 커서 (서버가 돌려주는 페이지네이션 토큰)
    private var nextCursor: Int?

    /// 현재 검색 컨텍스트의 키워드
    private var currentKeyword: String = ""

    /// 최신 검색 요청 식별자 — 이 값과 다른 응답은 stale 로 버립니다.
    private var latestRequestID: UUID = UUID()

    /// 다음 페이지 중복 호출 방지 플래그
    private var isFetchingNextPage: Bool = false

    /// 검색 시작 직전의 상태 — 취소 시 되돌릴 지점.
    ///
    /// `.loading` 자체를 되돌릴 지점으로 삼으면 취소 후 스피너에서 못 빠져나옵니다.
    /// 그래서 이미 `.loading` 인 동안에는 갱신하지 않습니다(디바운스로 `showLoading()` 이
    /// 여러 번 불릴 수 있음).
    private var stateBeforeSearch: Loadable<[ChallengerInfo]> = .idle

    // MARK: - Initializer

    /// - Parameter searchChallengersUseCase: 챌린저 검색 UseCase
    init(searchChallengersUseCase: SearchChallengersUseCaseProtocol) {
        self.searchChallengersUseCase = searchChallengersUseCase
    }

    // MARK: - Function (검색)

    /// 키워드로 챌린저를 검색합니다.
    func performSearch(keyword: String) async {
        let requestID = prepareSearch(keyword: keyword)
        await fetchFirstPage(keyword: keyword, requestID: requestID)
    }

    /// 현재 검색 키워드로 재검색합니다 (재시도 용도).
    func retrySearch() async {
        guard !currentKeyword.isEmpty else {
            resetSearchState()
            return
        }
        let keyword = currentKeyword
        let requestID = prepareSearch(keyword: keyword)
        await fetchFirstPage(keyword: keyword, requestID: requestID)
    }

    /// 검색 상태를 초기화합니다 (검색어가 비었을 때).
    func clearSearch() {
        // 진행 중인 요청의 응답이 빈 화면을 덮어쓰지 않도록 토큰도 함께 갱신한다.
        latestRequestID = UUID()
        resetSearchState()
    }

    /// 디바운스 대기 중임을 즉시 알리기 위한 로딩 전환.
    func showLoading() {
        beginLoading()
    }

    /// 다음 페이지를 조회해 기존 목록에 이어 붙입니다.
    func fetchNextPage() async {
        guard hasNext, let cursor = nextCursor, !isFetchingNextPage else { return }
        guard case .loaded(let existing) = loadState else { return }

        let requestID = latestRequestID
        let keyword = currentKeyword
        isFetchingNextPage = true
        defer { isFetchingNextPage = false }

        do {
            let page = try await searchChallengersUseCase.execute(
                keyword: keyword.nonEmptyKeyword,
                cursor: cursor,
                size: Constants.pageSize
            )
            // 페이지를 기다리는 사이 키워드가 바뀌었으면 다른 검색의 결과가 되므로 버린다.
            guard latestRequestID == requestID else { return }

            let knownKeys = Set(existing.map(\.selectionKey))
            let newChallengers = page.challengers.filter {
                !knownKeys.contains($0.selectionKey)
            }
            loadState = .loaded(existing + newChallengers)
            hasNext = page.hasNext
            nextCursor = page.nextCursor
        } catch {
            // 추가 페이지 실패는 이미 보고 있는 목록을 지우지 않는다.
            // 사용자는 스크롤을 다시 내려 재시도할 수 있고, 전체 실패 화면으로 바꾸면
            // 이미 확인한 검색 결과가 사라져 선택 흐름이 끊긴다.
            guard latestRequestID == requestID, !error.isCancellation else { return }
            hasNext = false
        }
    }

    // MARK: - Function (선택)

    /// 챌린저 선택/해제 토글 (같은 `memberId` 형제를 함께 처리)
    ///
    /// 동일 인물이 기수·파트별로 여러 행에 나올 수 있는데, 그룹 추가 API 는 멤버 단위라
    /// 한 행만 골라두면 나머지 행이 선택 안 된 상태로 남아 목록이 실제 선택과 어긋납니다.
    func toggleSelection(_ challenger: ChallengerInfo) {
        let isSelected = selectedKeys.contains(challenger.selectionKey)
        let siblings = allChallengers.filter { $0.memberId == challenger.memberId }

        for sibling in siblings {
            let key = sibling.selectionKey
            if isSelected {
                selectedKeys.remove(key)
                selectedChallengersMap.removeValue(forKey: key)
            } else {
                selectedKeys.insert(key)
                selectedChallengersMap[key] = sibling
            }
        }
    }

    /// 상위 화면에서 이미 선택돼 있던 목록을 선택 상태에 반영합니다.
    func initializeSelection(with challengers: [ChallengerInfo]) {
        let selectionMap = Dictionary(
            challengers.map { ($0.selectionKey, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        selectedKeys = Set(selectionMap.keys)
        selectedChallengersMap = selectionMap
    }

    /// 확정된 선택 목록을 반환합니다.
    ///
    /// 기존 선택 순서를 먼저 보존하고, 이번 검색에서 새로 고른 항목을 뒤에 붙입니다.
    /// 화면에 보이던 순서가 확인 한 번에 뒤섞이면 사용자가 무엇을 골랐는지 확인하기 어렵습니다.
    ///
    /// - Parameter previousSelection: 화면 진입 시점의 선택 목록
    func confirmedSelection(
        previousSelection: [ChallengerInfo]
    ) -> [ChallengerInfo] {
        var ordered: [ChallengerInfo] = []
        var handledKeys: Set<String> = []

        for challenger in previousSelection {
            let key = challenger.selectionKey
            guard let updated = selectedChallengersMap[key] else { continue }
            guard handledKeys.insert(key).inserted else { continue }
            ordered.append(updated)
        }

        let appended = selectedChallengersMap.values
            .sorted { $0.selectionKey < $1.selectionKey }
            .filter { handledKeys.insert($0.selectionKey).inserted }

        return ordered + appended
    }

    // MARK: - Private (조회)

    private func prepareSearch(keyword: String) -> UUID {
        let requestID = UUID()
        latestRequestID = requestID
        beginLoading()
        currentKeyword = keyword
        nextCursor = nil
        hasNext = false
        isFetchingNextPage = false
        return requestID
    }

    /// 로딩으로 전환하면서, 되돌릴 지점(`stateBeforeSearch`)을 한 번만 기록합니다.
    private func beginLoading() {
        if !loadState.isLoading {
            stateBeforeSearch = loadState
        }
        loadState = .loading
    }

    /// 첫 페이지를 조회합니다.
    ///
    /// `.task`/디바운스 취소로 던져지는 `CancellationError`·`NSURLErrorCancelled` 는 실패가
    /// 아니므로 이전 상태로 롤백합니다(형제 `MemberListViewModel` house 패턴).
    private func fetchFirstPage(keyword: String, requestID: UUID) async {
        do {
            let page = try await searchChallengersUseCase.execute(
                keyword: keyword.nonEmptyKeyword,
                cursor: nil,
                size: Constants.pageSize
            )
            guard latestRequestID == requestID else { return }
            hasNext = page.hasNext
            nextCursor = page.nextCursor
            loadState = .loaded(page.challengers)
        } catch is CancellationError {
            guard latestRequestID == requestID else { return }
            loadState = stateBeforeSearch
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            guard latestRequestID == requestID else { return }
            loadState = stateBeforeSearch
        } catch let error as AppError {
            failSearch(with: error, requestID: requestID)
        } catch let error as DomainError {
            failSearch(with: .domain(error), requestID: requestID)
        } catch let error as NetworkError {
            failSearch(with: .network(error), requestID: requestID)
        } catch let error as RepositoryError {
            failSearch(with: .repository(error), requestID: requestID)
        } catch {
            failSearch(
                with: .unknown(message: error.localizedDescription),
                requestID: requestID
            )
        }
    }

    private func failSearch(with error: AppError, requestID: UUID) {
        guard latestRequestID == requestID else { return }
        nextCursor = nil
        hasNext = false
        loadState = .failed(error)
    }

    private func resetSearchState() {
        currentKeyword = ""
        nextCursor = nil
        hasNext = false
        isFetchingNextPage = false
        loadState = .idle
        // 초기화 이후 도착한 취소가 지워진 결과를 되살리지 않도록 롤백 지점도 함께 비운다.
        stateBeforeSearch = .idle
    }
}

// MARK: - CSV Import

extension SearchChallengerViewModel {

    /// CSV 파일에서 이름/닉네임이 일치하는 챌린저를 일괄 선택합니다.
    ///
    /// 매칭 대상은 **현재 검색 결과에 올라온 챌린저**입니다 — 서버 재조회 없이 화면에 있는
    /// 목록만 훑기 때문에, 검색 결과 밖의 인원은 "매칭 실패"로 보고됩니다.
    ///
    /// - Parameter url: 사용자가 고른 CSV 파일 URL
    func importCSV(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            presentImportFailure(message: "파일에 접근할 수 없습니다.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let csvContent = try String(contentsOf: url, encoding: .utf8)
            applyCSVContent(csvContent)
        } catch {
            presentImportFailure(
                message: "CSV 파일을 읽을 수 없습니다: \(error.localizedDescription)"
            )
        }
    }

    /// CSV 내용을 파싱해 매칭되는 챌린저를 선택합니다.
    ///
    /// 첫 행은 헤더로 간주해 제외하고, `이름, 닉네임` 순의 열을 읽습니다.
    ///
    /// - Note: 파일 접근(보안 스코프 획득·읽기)과 분리된 진입점입니다. 파일 선택은
    ///   `fileImporter` 가 준 보안 스코프 URL 에서만 동작해 테스트로 재현할 수 없는 반면,
    ///   매칭 규칙은 그 자체로 검증 가치가 있어 seam 을 나눴습니다.
    func applyCSVContent(_ csvContent: String) {
        let rows = csvContent
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard rows.count > 1 else {
            presentImportFailure(message: "CSV 파일이 비어있습니다.")
            return
        }

        let dataRows = Array(rows.dropFirst())
        var matchedCount = 0
        var unmatchedNames: [String] = []

        for row in dataRows {
            let columns = row
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            guard let searchName = columns.first else { continue }
            let searchNickname = columns.count > 1 ? columns[1] : ""

            guard let matched = findChallenger(
                name: searchName,
                nickname: searchNickname
            ) else {
                unmatchedNames.append("\(searchName)/\(searchNickname)")
                continue
            }

            selectAllSiblings(of: matched)
            matchedCount += 1
        }

        presentImportResult(
            totalRows: dataRows.count,
            matchedCount: matchedCount,
            unmatchedNames: unmatchedNames
        )
    }

    /// 이름 또는 닉네임이 일치하는 첫 챌린저를 찾습니다.
    private func findChallenger(name: String, nickname: String) -> ChallengerInfo? {
        allChallengers.first { challenger in
            challenger.name == name || challenger.nickname == nickname
        }
    }

    /// 같은 `memberId` 를 가진 모든 행을 선택합니다 (탭 선택과 동일 규칙).
    private func selectAllSiblings(of challenger: ChallengerInfo) {
        let siblings = allChallengers.filter { $0.memberId == challenger.memberId }
        for sibling in siblings {
            selectedKeys.insert(sibling.selectionKey)
            selectedChallengersMap[sibling.selectionKey] = sibling
        }
    }

    private func presentImportResult(
        totalRows: Int,
        matchedCount: Int,
        unmatchedNames: [String]
    ) {
        var message = "총 \(totalRows)명 중 \(matchedCount)명 매칭 완료"
        if !unmatchedNames.isEmpty {
            message += "\n\n매칭 실패:\n\(unmatchedNames.joined(separator: ", "))"
        }

        alertPrompt = AlertPrompt(
            title: "CSV 가져오기 결과",
            message: message,
            positiveBtnTitle: "확인"
        )
    }

    private func presentImportFailure(message: String) {
        alertPrompt = AlertPrompt(
            title: "CSV 가져오기 실패",
            message: message,
            positiveBtnTitle: "확인"
        )
    }
}

// MARK: - Helper

private extension String {
    /// 비어 있으면 `nil` — 서버가 전체 검색으로 처리하도록 키워드를 생략한다.
    var nonEmptyKeyword: String? {
        isEmpty ? nil : self
    }
}
