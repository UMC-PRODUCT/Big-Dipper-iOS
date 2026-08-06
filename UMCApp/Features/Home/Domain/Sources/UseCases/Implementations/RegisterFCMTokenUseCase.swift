import Foundation

/// FCM 토큰 등록 UseCase 구현체.
public final class RegisterFCMTokenUseCase: RegisterFCMTokenUseCaseProtocol {

    // MARK: - Property

    private let repository: HomeRepositoryProtocol

    // MARK: - Init

    public init(repository: HomeRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(fcmToken: String) async throws {
        try await repository.registerFCMToken(fcmToken: fcmToken)
    }
}
