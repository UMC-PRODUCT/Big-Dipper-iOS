//
//  MyActivePostsView.swift
//  AppProduct
//
//  Created by euijjang97 on 2/15/26.
//

import SwiftUI

struct MyActivePostsView: View {
    // MARK: - Property

    @Environment(\.di) private var di
    @State private var viewModel: MyActivePostsViewModel
    private let shouldFetchOnAppear: Bool

    private var pathStore: PathStore {
        di.resolve(PathStore.self)
    }

    // MARK: - Init

    init(container: DIContainer, logType: MyActiveLogsType) {
        let provider = container.resolve(MyPageUseCaseProviding.self)
        self._viewModel = .init(
            initialValue: .init(
                logType: logType,
                useCaseProvider: provider
            )
        )
        self.shouldFetchOnAppear = true
    }

    init(
        container: DIContainer,
        logType: MyActiveLogsType,
        initialState: Loadable<[CommunityItemModel]>
    ) {
        let provider = container.resolve(MyPageUseCaseProviding.self)
        let vm = MyActivePostsViewModel(
            logType: logType,
            useCaseProvider: provider
        )
        vm.postsState = initialState

        self._viewModel = .init(initialValue: vm)
        self.shouldFetchOnAppear = false
    }

    // MARK: - Body

    var body: some View {
        content
            .navigation(naviTitle: viewModel.logType.navigationTitle, displayMode: .inline)
            .task {
                guard shouldFetchOnAppear else { return }
                await viewModel.fetchInitialIfNeeded()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.postsState {
        case .idle, .loading:
            Progress(message: "게시글 불러오는 중입니다.")
        case .failed(let error):
            errorView(error: error)
        case .loaded(let items):
            listView(items)
        }
    }

    private func listView(_ items: [CommunityItemModel]) -> some View {
        Group {
            if items.isEmpty {
                emptyStateView
            } else {
                postsList(items)
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label(
                "표시할 게시글이 없습니다.",
                systemImage: "text.page.slash"
            )
        }
    }

    private func postsList(_ items: [CommunityItemModel]) -> some View {
        List {
            ForEach(items) { item in
                postRow(item)
            }

            if viewModel.isLoadingMore {
                loadingMoreRow
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func postRow(_ item: CommunityItemModel) -> some View {
        CommunityItem(model: item) {
            pathStore.mypagePath.append(
                .community(.detail(postId: item.postId))
            )
        }
        .equatable()
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .task {
            await viewModel.loadMoreIfNeeded(currentItem: item)
        }
    }

    private var loadingMoreRow: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private func errorView(error: AppError) -> some View {
        ContentUnavailableView {
            Label("불러오지 못했어요", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error.localizedDescription)
        } actions: {
            Button("다시 시도") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.glassProminent)
        }
    }
}

private extension MyActiveLogsType {
    var navigationTitle: NavigationModifier.Navititle {
        switch self {
        case .myWritePost:
            return .myWrittenPosts
        case .myWriteComment:
            return .myCommentedPosts
        case .myScrapPost:
            return .myScrappedPosts
        }
    }
}

// MARK: - Preview

private var previewContainer: DIContainer {
    let container = DIContainer()
    container.register(PathStore.self) { PathStore() }
    container.register(MyPageUseCaseProviding.self) {
        MyPageUseCaseProviderPreviewMock()
    }
    return container
}

#Preview("Loaded") {
    myActivePostsPreview(state: .loaded(previewPosts))
}

#Preview("Loading") {
    myActivePostsPreview(state: .loading)
}

#Preview("Failed") {
    myActivePostsPreview(
        state: .failed(.unknown(message: "게시글 조회에 실패했습니다."))
    )
}

private func myActivePostsPreview(
    state: Loadable<[CommunityItemModel]>
) -> some View {
    let container = previewContainer
    return NavigationStack {
        MyActivePostsView(
            container: container,
            logType: .myWritePost,
            initialState: state
        )
    }
    .environment(\.di, container)
    .environment(ErrorHandler())
}

private struct MyPageUseCaseProviderPreviewMock: MyPageUseCaseProviding {
    let fetchMyPageProfileUseCase: FetchMyPageProfileUseCaseProtocol = FetchMyPageProfilePreviewUseCase()
    let addChallengerRecordUseCase: AddChallengerRecordUseCaseProtocol = AddChallengerRecordPreviewUseCase()
    let updateMyPageProfileImageUseCase: UpdateMyPageProfileImageUseCaseProtocol = UpdateMyPageProfileImagePreviewUseCase()
    let updateMyPageProfileLinksUseCase: UpdateMyPageProfileLinksUseCaseProtocol = UpdateMyPageProfileLinksPreviewUseCase()
    let deleteMemberUseCase: DeleteMemberUseCaseProtocol = DeleteMemberPreviewUseCase()
    let fetchMyPostsUseCase: FetchMyPostsUseCaseProtocol = FetchMyPostsPreviewUseCase()
    let fetchMyCommentedPostsUseCase: FetchMyCommentedPostsUseCaseProtocol = FetchMyCommentedPostsPreviewUseCase()
    let fetchMyScrappedPostsUseCase: FetchMyScrappedPostsUseCaseProtocol = FetchMyScrappedPostsPreviewUseCase()
    let fetchTermsUseCase: FetchTermsUseCaseProtocol = FetchTermsPreviewUseCase()
}

private struct AddChallengerRecordPreviewUseCase: AddChallengerRecordUseCaseProtocol {
    func execute(code: String) async throws {
        _ = code
    }
}

private struct FetchMyPageProfilePreviewUseCase: FetchMyPageProfileUseCaseProtocol {
    func execute() async throws -> ProfileData {
        ProfileData(
            challengeId: 1,
            challangerInfo: ChallengerInfo(
                memberId: 1,
                gen: 8,
                name: "홍길동",
                nickname: "길동",
                schoolName: "UMC University",
                profileImage: nil,
                part: .front(type: .ios)
            ),
            socialConnections: [
                .init(memberOAuthId: 1, socialType: .kakao)
            ],
            activityLogs: [],
            profileLink: []
        )
    }
}

private struct UpdateMyPageProfileImagePreviewUseCase: UpdateMyPageProfileImageUseCaseProtocol {
    func execute(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        try await FetchMyPageProfilePreviewUseCase().execute()
    }
}

private struct UpdateMyPageProfileLinksPreviewUseCase: UpdateMyPageProfileLinksUseCaseProtocol {
    func execute(
        profileLinks: [ProfileLink]
    ) async throws -> ProfileData {
        var profile = try await FetchMyPageProfilePreviewUseCase().execute()
        profile.profileLink = profileLinks
        return profile
    }
}

private struct DeleteMemberPreviewUseCase: DeleteMemberUseCaseProtocol {
    func execute() async throws {}
}

private struct FetchMyPostsPreviewUseCase: FetchMyPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        MyActivePostPage(
            items: previewPosts,
            page: query.page,
            hasNext: false
        )
    }
}

private struct FetchMyCommentedPostsPreviewUseCase: FetchMyCommentedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await FetchMyPostsPreviewUseCase().execute(query: query)
    }
}

private struct FetchMyScrappedPostsPreviewUseCase: FetchMyScrappedPostsUseCaseProtocol {
    func execute(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await FetchMyPostsPreviewUseCase().execute(query: query)
    }
}

private struct FetchTermsPreviewUseCase: FetchTermsUseCaseProtocol {
    func execute(termsType: String) async throws -> MyPageTerms {
        MyPageTerms(
            id: "1",
            link: "https://example.com/\(termsType.lowercased())",
            isMandatory: true
        )
    }
}

private let previewPosts: [CommunityItemModel] = [
    .init(
        postId: 1,
        userId: 1,
        category: .free,
        title: "스터디원 모집합니다",
        content: "Spring Boot 스터디원 모집합니다.",
        profileImage: nil,
        userName: "홍길동",
        userNickname: "길동이",
        part: .server(type: .spring),
        createdAt: Date(),
        likeCount: 42,
        commentCount: 5,
        scrapCount: 0,
        isLiked: true,
        isAuthor: true,
        lightningInfo: nil
    ),
    .init(
        postId: 1,
        userId: 1,
        category: .question,
        title: "iOS 네트워크 구조 질문",
        content: "Moya + Clean Architecture 조합에서 repository 계층 경계 질문입니다.",
        profileImage: nil,
        userName: "홍길동",
        userNickname: "길동이",
        part: .front(type: .ios),
        createdAt: Date(),
        likeCount: 8,
        commentCount: 3,
        scrapCount: 0,
        isLiked: false,
        isAuthor: true,
        lightningInfo: nil
    )
]
