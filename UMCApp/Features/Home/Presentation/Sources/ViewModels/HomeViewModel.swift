import CoreDI
import Foundation
import HomeDomain
import UMCFoundation

/// 홈 화면(시즌/세대 카드) ViewModel
@Observable
@MainActor
public final class HomeViewModel {

    // MARK: - Property

    public private(set) var seasonState: Loadable<[SeasonType]> = .idle
    public private(set) var generationState: Loadable<[HomeGeneration]> = .idle

    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol

    // MARK: - Init

    public init(container: DIContainer) {
        fetchMyProfileUseCase = container.resolve(FetchMyProfileUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 아직 로딩을 시작하지 않았을 때만 프로필을 조회한다. `.task`의 최초 트리거로 사용한다.
    public func fetchProfileIfNeeded() async {
        guard seasonState.isIdle else { return }
        await fetchProfile()
    }

    /// 내 프로필을 조회해 시즌/세대 카드 상태를 갱신한다. 실패 시 인라인 `.failed` 상태로 표시한다.
    public func fetchProfile() async {
        if seasonState.isLoading { return }

        let previousSeasonState = seasonState
        let previousGenerationState = generationState
        seasonState = .loading
        generationState = .loading

        do {
            let profile = try await fetchMyProfileUseCase.execute()
            seasonState = .loaded(profile.seasonTypes)
            generationState = .loaded(sortedByGenerationDescending(profile.generations))
        } catch is CancellationError {
            seasonState = previousSeasonState
            generationState = previousGenerationState
        } catch let error as RepositoryError {
            setFailed(.repository(error))
        } catch let error as NetworkError {
            setFailed(.network(error))
        } catch let error as AppError {
            setFailed(error)
        } catch {
            setFailed(.unknown(message: error.localizedDescription))
        }
    }

    // MARK: - Private Function

    private func setFailed(_ error: AppError) {
        seasonState = .failed(error)
        generationState = .failed(error)
    }

    /// 기수(`gen`)는 서버 정수를 `String`으로 보존하므로 정렬 시점에만 `Int`로 환원한다.
    private func sortedByGenerationDescending(_ generations: [HomeGeneration]) -> [HomeGeneration] {
        generations.sorted { (Int($0.gen) ?? 0) > (Int($1.gen) ?? 0) }
    }
}
