import CoreDI
import CoreNetwork
import MyPageData
import MyPageDomain
import MyPagePresentation
import UMCFoundation

// #816 화면 조립 전 전체 의존성 등록 완료 — MyPage Repository/UseCase/Provider를 모두 등록한다.
// (승인 대기(#945) 화면의 회원 탈퇴 액션에 쓰이던 최소 등록에서 확장)
// `StorageRepositoryProtocol`은 `registerNoticeDependencies()`에서 이미 등록되므로 여기서는
// 재등록하지 않는다(UMCAppApp.swift 부트스트랩 순서 참고).
// 화면 조립(View↔ViewModel 배선, NavigationDestination 등) 잔여 범위는 #816에서 이어서 진행한다.
extension DIContainer {
    func registerMyPageDependencies() {
        register(MyPageRepositoryProtocol.self) {
            MyPageRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                storageRepository: self.resolve(StorageRepositoryProtocol.self)
            )
        }

        register(FetchMyPageProfileUseCaseProtocol.self) {
            FetchMyPageProfileUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(AddChallengerRecordUseCaseProtocol.self) {
            AddChallengerRecordUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(UpdateMyPageProfileImageUseCaseProtocol.self) {
            UpdateMyPageProfileImageUseCase(
                repository: self.resolve(MyPageRepositoryProtocol.self)
            )
        }
        register(UpdateMyPageProfileLinksUseCaseProtocol.self) {
            UpdateMyPageProfileLinksUseCase(
                repository: self.resolve(MyPageRepositoryProtocol.self)
            )
        }
        register(DeleteMemberUseCaseProtocol.self) {
            DeleteMemberUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(FetchMyPostsUseCaseProtocol.self) {
            FetchMyPostsUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(FetchMyCommentedPostsUseCaseProtocol.self) {
            FetchMyCommentedPostsUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(FetchMyScrappedPostsUseCaseProtocol.self) {
            FetchMyScrappedPostsUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
        register(FetchTermsUseCaseProtocol.self) {
            FetchTermsUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }

        // MyPageViewModel이 실제로 resolve하는 진입점 — 개별 UseCase Protocol 대신
        // `MyPageUseCaseProviding` 하나로 묶어 주입받는다.
        register(MyPageUseCaseProviding.self) {
            MyPageUseCaseProvider(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
    }
}
