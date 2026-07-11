import CoreDI
import Foundation
import HomeDomain
import NoticeDomain
import UMCFoundation

/// 홈 화면(시즌/세대 카드/최근 공지) ViewModel
@Observable
@MainActor
public final class HomeViewModel {

    // MARK: - Property

    public private(set) var seasonState: Loadable<[SeasonType]> = .idle
    public private(set) var generationState: Loadable<[HomeGeneration]> = .idle
    public private(set) var recentNoticeState: Loadable<[NoticeItemModel]> = .idle

    private let fetchMyProfileUseCase: FetchHomeProfileUseCaseProtocol
    private let fetchRecentNoticesUseCase: FetchRecentNoticesUseCaseProtocol

    // MARK: - Init

    public init(container: DIContainer) {
        fetchMyProfileUseCase = container.resolve(FetchHomeProfileUseCaseProtocol.self)
        fetchRecentNoticesUseCase = container.resolve(FetchRecentNoticesUseCaseProtocol.self)
    }

    // MARK: - Function

    /// 아직 로딩을 시작하지 않았을 때만 프로필을 조회한다. `.task`의 최초 트리거로 사용한다.
    public func fetchProfileIfNeeded() async {
        guard seasonState.isIdle else { return }
        await fetchProfile()
    }

    /// 내 프로필을 조회해 시즌/세대 카드 상태를 갱신한다. 실패 시 인라인 `.failed` 상태로 표시한다.
    /// 세대 조회가 성공하면 최신 기수를 기준으로 최근 공지도 함께 조회한다.
    public func fetchProfile() async {
        if seasonState.isLoading { return }

        let previousSeasonState = seasonState
        let previousGenerationState = generationState
        seasonState = .loading
        generationState = .loading

        do {
            let profile = try await fetchMyProfileUseCase.execute()
            let sortedGenerations = sortedByGenerationDescending(profile.generations)
            seasonState = .loaded(profile.seasonTypes)
            generationState = .loaded(sortedGenerations)
            await fetchRecentNotices(latestGisuId: sortedGenerations.first?.gisuId)
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

    /// 최신 기수의 최근 공지 5건을 조회한다. 소속 기수가 없으면 빈 목록으로 처리한다.
    private func fetchRecentNotices(latestGisuId: String?) async {
        guard let gisuId = latestGisuId, !gisuId.isEmpty else {
            recentNoticeState = .loaded([])
            return
        }

        recentNoticeState = .loading

        do {
            let notices = try await fetchRecentNoticesUseCase.execute(gisuId: gisuId)
            recentNoticeState = .loaded(notices)
        } catch is CancellationError {
            recentNoticeState = .idle
        } catch let error as RepositoryError {
            recentNoticeState = .failed(.repository(error))
        } catch let error as NetworkError {
            recentNoticeState = .failed(.network(error))
        } catch let error as AppError {
            recentNoticeState = .failed(error)
        } catch {
            recentNoticeState = .failed(.unknown(message: error.localizedDescription))
        }
    }

    private func setFailed(_ error: AppError) {
        seasonState = .failed(error)
        generationState = .failed(error)
        recentNoticeState = .failed(error)
    }

    /// 기수(`gen`)는 서버 정수를 `String`으로 보존하므로 정렬 시점에만 `Int`로 환원한다.
    private func sortedByGenerationDescending(_ generations: [HomeGeneration]) -> [HomeGeneration] {
        generations.sorted { (Int($0.gen) ?? 0) > (Int($1.gen) ?? 0) }
    }
}
