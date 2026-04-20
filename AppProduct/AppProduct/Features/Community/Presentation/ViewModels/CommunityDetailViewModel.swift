//
//  CommunityDetailViewModel.swift
//  AppProduct
//
//  Created by 김미주 on 1/20/26.
//

import Foundation

@Observable
class CommunityDetailViewModel {
    enum PostDetailFailureReason: Equatable {
        case unavailable
        case generic
    }

    // MARK: - Property

    private let useCaseProvider: CommunityUseCaseProviding
    private let authorizationUseCase: AuthorizationUseCaseProtocol
    private let errorHandler: ErrorHandler
    private let postId: Int

    private(set) var postItem: CommunityItemModel?
    private(set) var comments: Loadable<[CommunityCommentModel]> = .idle
    private(set) var postDetailState: Loadable<CommunityItemModel> = .idle
    private(set) var postDetailFailureReason: PostDetailFailureReason = .generic
    private(set) var isDeleting: Bool = false
    private(set) var isDeletingComment: Bool = false
    private(set) var isScrapToggling: Bool = false
    private(set) var isLikeToggling: Bool = false
    private(set) var isPostingComment: Bool = false
    private(set) var commentDeletePermissions: [Int: Bool] = [:]
    private(set) var isPermissionsLoaded: Bool = false
    private(set) var postPermission: ResourcePermission?

    var commentText: String = ""
    var alertPrompt: AlertPrompt?

    /// 댓글 작성 완료 트리거 (게스트 토스트 표시용)
    var didCompleteComment: Bool = false

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        postId: Int
    ) {
        self.useCaseProvider = container.resolve(CommunityUseCaseProviding.self)
        self.authorizationUseCase = container.resolve(AuthorizationUseCaseProtocol.self)
        self.errorHandler = errorHandler
        self.postId = postId
    }

    // MARK: - Function

    /// 게시글 상세 조회
    @MainActor
    func fetchPostDetail() async {
        postDetailState = .loading
        postDetailFailureReason = .generic

        do {
            let detail = try await useCaseProvider.fetchPostDetailUseCase.execute(postId: postId)
            postItem = detail
            postDetailState = .loaded(detail)
        } catch let error as AppError {
            postDetailFailureReason = resolvePostDetailFailureReason(from: error)
            postDetailState = .failed(error)
        } catch let error as NetworkError {
            postDetailFailureReason = resolvePostDetailFailureReason(from: error)
            postDetailState = .failed(.network(error))
        } catch {
            postDetailState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 게시글 권한 조회
    @MainActor
    func fetchPostPermission() async {
        do {
            postPermission = try await authorizationUseCase.getResourcePermission(
                resourceType: .communityPost,
                resourceId: postId
            )
        } catch {
            postPermission = nil
        }
    }

    /// 게시글 수정 권한 여부
    var canEditPost: Bool {
        postPermission?.has(.edit) ?? false
    }

    /// 게시글 삭제 권한 여부
    var canDeletePost: Bool {
        postPermission?.has(.delete) ?? false
    }

    /// 댓글 목록 조회
    @MainActor
    func fetchComments() async {
        comments = .loading

        do {
            let fetchedComments = try await useCaseProvider.fetchCommentUseCase.execute(postId: postId)
            comments = .loaded(fetchedComments)

            // 댓글 권한 조회
            await fetchCommentPermissions(for: fetchedComments)
        } catch let error as AppError {
            comments = .failed(error)
        } catch {
            comments = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 댓글 권한 조회
    @MainActor
    private func fetchCommentPermissions(for comments: [CommunityCommentModel]) async {
        isPermissionsLoaded = false

        // 모든 댓글에 대한 권한을 병렬로 조회
        await withTaskGroup(of: (Int, Bool).self) { group in
            for comment in comments {
                group.addTask { [weak self] in
                    guard let self = self else { return (comment.commentId, false) }
                    do {
                        let permission = try await self.authorizationUseCase.getResourcePermission(
                            resourceType: .comment,
                            resourceId: comment.commentId
                        )
                        let canDelete = await permission.has(.delete)
                        return (comment.commentId, canDelete)
                    } catch {
                        return (comment.commentId, false)
                    }
                }
            }

            for await (commentId, canDelete) in group {
                commentDeletePermissions[commentId] = canDelete
            }
        }

        isPermissionsLoaded = true
    }

    /// 댓글 삭제 권한 확인
    func canDeleteComment(commentId: Int) -> Bool {
        let result = commentDeletePermissions[commentId] ?? false
        return result
    }

    /// 게시글 삭제
    @MainActor
    func deletePost() async -> Bool {
        isDeleting = true

        do {
            try await useCaseProvider.deletePostUseCase.execute(postId: postItem?.postId ?? 0)
            isDeleting = false
            return true
        } catch {
            isDeleting = false
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "deletePost",
                retryAction: { [weak self] in
                    _ = await self?.deletePost()
                }
            ))
            return false
        }
    }

    /// 댓글 삭제
    @MainActor
    func deleteComment(commentId: Int) async {
        isDeletingComment = true

        do {
            try await useCaseProvider.deleteCommentUseCase.execute(
                postId: postItem?.postId ?? 0,
                commentId: commentId
            )
            isDeletingComment = false
            // 댓글 삭제 후 목록 새로고침
            await fetchComments()
        } catch {
            isDeletingComment = false
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "deleteComment",
                retryAction: { [weak self] in
                    await self?.deleteComment(commentId: commentId)
                }
            ))
        }
    }

    /// 게시글 스크랩
    @MainActor
    func toggleScrap() async {
        guard !isScrapToggling, var item = postItem else { return }
        isScrapToggling = true

        // 낙관적 업데이트
        let previousScrapState = item.isScrapped
        let previousScrapCount = item.scrapCount
        item.isScrapped.toggle()
        item.scrapCount += item.isScrapped ? 1 : -1
        postItem = item

        do {
            try await useCaseProvider.postScrapUseCase.execute(postId: item.postId)
            isScrapToggling = false
        } catch {
            // 실패 시 이전 상태로 롤백
            var rollbackItem = item
            rollbackItem.isScrapped = previousScrapState
            rollbackItem.scrapCount = previousScrapCount
            postItem = rollbackItem
            isScrapToggling = false
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "toggleScrap",
                retryAction: { [weak self] in
                    await self?.toggleScrap()
                }
            ))
        }
    }

    /// 게시글 좋아요
    @MainActor
    func toggleLike() async {
        guard !isLikeToggling, var item = postItem else { return }
        isLikeToggling = true

        // 낙관적 업데이트
        let previousLikeState = item.isLiked
        let previousLikeCount = item.likeCount
        item.isLiked.toggle()
        item.likeCount += item.isLiked ? 1 : -1
        postItem = item

        do {
            try await useCaseProvider.postLikeUseCase.execute(postId: item.postId)
            isLikeToggling = false
        } catch {
            // 실패 시 이전 상태로 롤백
            var rollbackItem = item
            rollbackItem.isLiked = previousLikeState
            rollbackItem.likeCount = previousLikeCount
            postItem = rollbackItem
            isLikeToggling = false
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "toggleLike",
                retryAction: { [weak self] in
                    await self?.toggleLike()
                }
            ))
        }
    }

    /// 댓글 작성
    @MainActor
    func postComment(content: String, parentId: Int) async {
        guard !isPostingComment else { return }
        isPostingComment = true

        let request = PostCommentRequest(content: content, parentId: parentId)

        do {
            try await useCaseProvider.postCommentUseCase.execute(
                postId: postItem?.postId ?? 0,
                request: request
            )
            isPostingComment = false
            didCompleteComment = true
            // 댓글 작성 후 목록 새로고침
            await fetchComments()
        } catch {
            isPostingComment = false
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "postComment",
                retryAction: { [weak self] in
                    await self?.postComment(content: content, parentId: parentId)
                }
            ))
        }
    }

    /// 게시글 상세 새로고침 (상세 조회 API 사용)
    @MainActor
    func refreshPostDetail() async {
        postDetailState = .loading

        do {
            let updatedPost = try await useCaseProvider.fetchPostDetailUseCase.execute(postId: postItem?.postId ?? 0)
            postItem = updatedPost
            postDetailState = .loaded(updatedPost)
        } catch let error as AppError {
            postDetailState = .failed(error)
        } catch {
            postDetailState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 게시글 신고
    @MainActor
    func reportPost() async {
        do {
            try await useCaseProvider.reportPostUseCase.execute(postId: postItem?.postId ?? 0)
            alertPrompt = AlertPrompt(
                title: "신고 완료",
                message: "해당 게시글이 신고되었습니다.",
                positiveBtnTitle: "확인"
            )
        } catch let error as RepositoryError {
            // 409 에러: 이미 신고한 게시글
            if case .serverError(let code, let message) = error, code == "409" {
                alertPrompt = AlertPrompt(
                    title: "신고 불가",
                    message: message ?? "이미 신고한 게시글입니다.",
                    positiveBtnTitle: "확인"
                )
            } else {
                errorHandler.handle(error, context: ErrorContext(
                    feature: "Community",
                    action: "reportPost",
                    retryAction: { [weak self] in
                        await self?.reportPost()
                    }
                ))
            }
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "reportPost",
                retryAction: { [weak self] in
                    await self?.reportPost()
                }
            ))
        }
    }

    /// 댓글 신고
    @MainActor
    func reportComment(commentId: Int) async {
        do {
            try await useCaseProvider.reportCommentUseCase.execute(commentId: commentId)
            alertPrompt = AlertPrompt(
                title: "신고 완료",
                message: "해당 댓글이 신고되었습니다.",
                positiveBtnTitle: "확인"
            )
        } catch let error as RepositoryError {
            // 409 에러: 이미 신고한 댓글
            if case .serverError(let code, let message) = error, code == "409" {
                alertPrompt = AlertPrompt(
                    title: "신고 불가",
                    message: message ?? "이미 신고한 댓글입니다.",
                    positiveBtnTitle: "확인"
                )
            } else {
                errorHandler.handle(error, context: ErrorContext(
                    feature: "Community",
                    action: "reportComment",
                    retryAction: { [weak self] in
                        await self?.reportComment(commentId: commentId)
                    }
                ))
            }
        } catch {
            errorHandler.handle(error, context: ErrorContext(
                feature: "Community",
                action: "reportComment",
                retryAction: { [weak self] in
                    await self?.reportComment(commentId: commentId)
                }
            ))
        }
    }

}

private extension CommunityDetailViewModel {
    func resolvePostDetailFailureReason(
        from error: AppError
    ) -> PostDetailFailureReason {
        guard case .network(let networkError) = error else {
            return .generic
        }

        return resolvePostDetailFailureReason(from: networkError)
    }

    func resolvePostDetailFailureReason(
        from error: NetworkError
    ) -> PostDetailFailureReason {
        guard case .requestFailed(404, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = json["code"] as? String,
              code == "MEMBER-0001"
        else {
            return .generic
        }

        return .unavailable
    }
}
