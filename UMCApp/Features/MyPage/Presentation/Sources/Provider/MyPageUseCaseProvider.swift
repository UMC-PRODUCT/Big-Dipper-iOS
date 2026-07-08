//
//  MyPageUseCaseProvider.swift
//  MyPagePresentation
//
//  Created by One on 5/24/26.
//

import Foundation
import MyPageDomain

/// MyPage Presentation 레이어에서 사용하는 UseCase Bundle Protocol.
///
/// ViewModel이 여러 UseCase를 개별 주입받지 않고 Provider 한 개로 묶어 받습니다.
public protocol MyPageUseCaseProviding {
    /// 내 프로필 조회 UseCase
    var fetchMyPageProfileUseCase: FetchMyPageProfileUseCaseProtocol { get }
    /// 챌린저 연결 UseCase
    var addChallengerRecordUseCase: AddChallengerRecordUseCaseProtocol { get }
    /// 프로필 이미지변경 UseCase
    var updateMyPageProfileImageUseCase: UpdateMyPageProfileImageUseCaseProtocol { get }
    /// 프로필 외부 링크 수정 UseCase
    var updateMyPageProfileLinksUseCase: UpdateMyPageProfileLinksUseCaseProtocol { get }
    /// 회원 탈퇴 UseCase
    var deleteMemberUseCase: DeleteMemberUseCaseProtocol { get }
    /// 내 글 조회 UseCase
    var fetchMyPostsUseCase: FetchMyPostsUseCaseProtocol { get }
    /// 댓글 단 글들 조회 UseCase
    var fetchMyCommentedPostsUseCase: FetchMyCommentedPostsUseCaseProtocol { get }
    /// 스크랩한 글들 조회 UseCase
    var fetchMyScrappedPostsUseCase: FetchMyScrappedPostsUseCaseProtocol { get }
    /// 약관 조회 UseCase
    var fetchTermsUseCase: FetchTermsUseCaseProtocol { get }
}

/// `MyPageUseCaseProviding`의 기본 구현체.
///
/// 단일 `MyPageRepositoryProtocol`을 주입받아 UseCase 인스턴스를 한 번씩 생성합니다.
public final class MyPageUseCaseProvider: MyPageUseCaseProviding {

    // MARK: - Property
    
    public let fetchMyPageProfileUseCase: FetchMyPageProfileUseCaseProtocol
    
    public let addChallengerRecordUseCase: AddChallengerRecordUseCaseProtocol
    
    public let updateMyPageProfileImageUseCase: UpdateMyPageProfileImageUseCaseProtocol
    
    public let updateMyPageProfileLinksUseCase: UpdateMyPageProfileLinksUseCaseProtocol
    
    public let deleteMemberUseCase: DeleteMemberUseCaseProtocol
    
    public let fetchMyPostsUseCase: FetchMyPostsUseCaseProtocol
    
    public let fetchMyCommentedPostsUseCase: FetchMyCommentedPostsUseCaseProtocol
    
    public let fetchMyScrappedPostsUseCase: FetchMyScrappedPostsUseCaseProtocol
    
    public let fetchTermsUseCase: FetchTermsUseCaseProtocol
    
    // MARK: - Function

    public init(repository: MyPageRepositoryProtocol) {
        self.fetchMyPageProfileUseCase = FetchMyPageProfileUseCase(repository: repository)
        self.addChallengerRecordUseCase = AddChallengerRecordUseCase(repository: repository)
        self.updateMyPageProfileImageUseCase = UpdateMyPageProfileImageUseCase(repository: repository)
        self.updateMyPageProfileLinksUseCase = UpdateMyPageProfileLinksUseCase(repository: repository)
        self.deleteMemberUseCase = DeleteMemberUseCase(repository: repository)
        self.fetchMyPostsUseCase = FetchMyPostsUseCase(repository: repository)
        self.fetchMyCommentedPostsUseCase = FetchMyCommentedPostsUseCase(repository: repository)
        self.fetchMyScrappedPostsUseCase = FetchMyScrappedPostsUseCase(repository: repository)
        self.fetchTermsUseCase = FetchTermsUseCase(repository: repository)
    }
}
