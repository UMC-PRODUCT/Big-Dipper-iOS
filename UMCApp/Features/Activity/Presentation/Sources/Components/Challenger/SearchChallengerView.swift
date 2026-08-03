//
//  SearchChallengerView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation
import UniformTypeIdentifiers

/// 챌린저를 이름/닉네임으로 검색해 선택하는 화면.
///
/// 상위 화면이 들고 있는 선택 목록(`selectedChallengers`)을 바인딩으로 받아, 확인 시 확정된
/// 선택으로 갱신합니다. CSV 파일로 다수 인원을 한 번에 고를 수도 있습니다.
///
/// `SelectedChallengerView` 의 `NavigationStack` 안으로 push 되므로 자체 스택을 만들지 않습니다.
struct SearchChallengerView: View {

    // MARK: - Property

    /// 상위 화면과 공유하는 선택된 챌린저 목록
    @Binding var selectedChallengers: [ChallengerInfo]

    @State private var viewModel: SearchChallengerViewModel

    /// 검색창 입력 (로컬 상태로 둬 입력 지연을 피한다)
    @State private var searchText = ""

    /// 디바운스용 검색 Task
    @State private var searchTask: Task<Void, Never>?

    /// 화면 진입 시점의 선택 목록 — 확인 시 순서 보존 기준
    @State private var initialSelection: [ChallengerInfo] = []

    /// 진입 선택 복원을 1회로 제한하는 플래그.
    ///
    /// `initialSelection.isEmpty` 로 판단하면 "선택 없이 진입한 경우"에 `.task` 가 다시 돌 때
    /// 아직 확정하지 않은 선택이 통째로 초기화된다(`selectedChallengers` 는 확인 시점에만 갱신).
    @State private var didRestoreSelection = false

    // MARK: - Constants

    fileprivate enum Constants {
        static let searchDebounce: Duration = .milliseconds(300)
        static let searchPrompt: String = "이름 또는 닉네임으로 검색해보세요"
        static let loadingMessage: String = "챌린저 목록을 불러오는 중입니다."
        static let failedTitle: String = "챌린저 검색에 실패했어요"
        static let failedSystemImage: String = "exclamationmark.triangle"
        static let idleTitle: String = "검색된 챌린저가 없습니다"
        static let idleDescription: String = "이름 또는 닉네임으로 챌린저를 검색해보세요."
        static let idleSystemImage: String = "magnifyingglass"
        static let emptyTitle: String = "검색 결과가 없습니다"
    }

    // MARK: - Init

    /// - Parameters:
    ///   - useCase: 챌린저 검색 UseCase (상위에서 DI 로 해석해 주입)
    ///   - selectedChallengers: 상위 화면의 선택 목록 바인딩
    init(
        useCase: SearchChallengersUseCaseProtocol,
        selectedChallengers: Binding<[ChallengerInfo]>
    ) {
        self._selectedChallengers = selectedChallengers
        self._viewModel = State(
            initialValue: SearchChallengerViewModel(searchChallengersUseCase: useCase)
        )
    }

    // MARK: - Body

    var body: some View {
        stateContent
            .searchable(text: $searchText, prompt: Constants.searchPrompt)
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .navigationTitle(NavigationTitle.Activity.searchChallenger.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolBarCollection.ConfirmBtn(action: confirmSelection)
            }
            .fileImporter(
                isPresented: $viewModel.showCSVImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleCSVImport(result)
            }
            .alertPrompt(item: $viewModel.alertPrompt)
            .task {
                guard !didRestoreSelection else { return }
                didRestoreSelection = true
                initialSelection = selectedChallengers
                viewModel.initializeSelection(with: selectedChallengers)
            }
            .onChange(of: searchText) { _, newValue in
                handleSearchChanged(newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
    }

    // MARK: - View Components

    @ViewBuilder
    private var stateContent: some View {
        switch viewModel.loadState {
        case .idle:
            idleView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loading:
            Progress(message: Constants.loadingMessage, size: .regular)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let challengers):
            if challengers.isEmpty {
                emptyResultView
            } else {
                resultList(challengers)
            }

        case .failed(let error):
            // 재시도를 누르면 `.loading` 으로 전이돼 위 분기가 스피너를 그리므로,
            // 이 분기에서는 재시도 진행 표시가 필요 없다(형제 `ChallengerMemberListView` 동일).
            RetryContentUnavailableView(
                title: Constants.failedTitle,
                systemImage: Constants.failedSystemImage,
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.retrySearch()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func resultList(_ challengers: [ChallengerInfo]) -> some View {
        ChallengerFormView(
            challengers: .constant(challengers),
            selectedKeys: $viewModel.selectedKeys,
            showCheckBox: true,
            onTap: viewModel.toggleSelection,
            onBottomReached: {
                Task { await viewModel.fetchNextPage() }
            }
        )
    }

    private var idleView: some View {
        ContentUnavailableView(
            Constants.idleTitle,
            systemImage: Constants.idleSystemImage,
            description: Text(Constants.idleDescription)
        )
    }

    private var emptyResultView: some View {
        ContentUnavailableView(
            Constants.emptyTitle,
            systemImage: Constants.idleSystemImage,
            description: Text("'\(searchText)'에 대한 검색 결과를 찾을 수 없습니다.\n다른 검색어를 입력해보세요.")
        )
    }

    // MARK: - Function

    /// 검색어 변경 시 디바운스 후 검색을 실행합니다.
    private func handleSearchChanged(_ newValue: String) {
        searchTask?.cancel()

        let keyword = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else {
            viewModel.clearSearch()
            return
        }

        // 대기 중임을 즉시 보여줘 입력과 결과 사이의 공백을 없앤다.
        viewModel.showLoading()
        searchTask = Task {
            try? await Task.sleep(for: Constants.searchDebounce)
            guard !Task.isCancelled else { return }
            await viewModel.performSearch(keyword: keyword)
        }
    }

    /// 선택을 확정해 상위 화면 목록에 반영합니다.
    private func confirmSelection() {
        selectedChallengers = viewModel.confirmedSelection(
            previousSelection: initialSelection
        )
    }

    private func handleCSVImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            viewModel.importCSV(from: url)

        case .failure(let error):
            viewModel.alertPrompt = AlertPrompt(
                title: "CSV 가져오기 실패",
                message: "파일 선택 실패: \(error.localizedDescription)",
                positiveBtnTitle: "확인"
            )
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SearchChallengerView") {
    @Previewable @State var selected: [ChallengerInfo] = []

    NavigationStack {
        SearchChallengerView(
            useCase: PreviewSearchChallengersUseCase(),
            selectedChallengers: $selected
        )
    }
}
#endif
