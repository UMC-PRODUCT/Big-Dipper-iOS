import CoreDI
import CoreNetwork
import MyPageData
import MyPageDomain
import UMCFoundation

// 승인 대기(#945) 화면의 회원 탈퇴 액션에 필요한 최소 의존성만 등록한다.
// #816에서 전체 MyPage 배선(프로필/활동 게시글/약관 등) 시 이 파일을 확장한다.
extension DIContainer {
    func registerMyPageDependencies() {
        register(MyPageRepositoryProtocol.self) {
            MyPageRepository(
                adapter: self.resolve(MoyaNetworkAdapter.self),
                storageRepository: self.resolve(StorageRepositoryProtocol.self)
            )
        }
        register(DeleteMemberUseCaseProtocol.self) {
            DeleteMemberUseCase(repository: self.resolve(MyPageRepositoryProtocol.self))
        }
    }
}
