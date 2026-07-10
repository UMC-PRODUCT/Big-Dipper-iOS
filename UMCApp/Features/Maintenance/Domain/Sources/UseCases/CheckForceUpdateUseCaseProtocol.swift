/// 강제 업데이트 필요 여부를 판정하는 UseCase 인터페이스.
public protocol CheckForceUpdateUseCaseProtocol {
    func execute() async -> Bool
}
