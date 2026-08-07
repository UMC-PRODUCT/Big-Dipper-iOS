import Foundation

/// 알림 분류 UseCase 구현체.
///
/// 제목과 본문을 한 문자열로 합쳐 CoreML(로드된 경우)로 먼저 분류하고, 모델 미로드/예측 실패
/// 시 키워드 매칭으로 fallback한다.
public final class ClassifyNoticeUseCase: ClassifyNoticeUseCaseProtocol {

    // MARK: - Property

    private let repository: NoticeClassifierRepositoryProtocol

    // MARK: - Init

    public init(repository: NoticeClassifierRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Function

    public func execute(title: String, content: String) -> NoticeAlarmType {
        let text = "\(title) \(content)"

        if repository.isModelLoaded, let mlResult = repository.classifyWithML(text: text) {
            return mlResult
        }
        return repository.classifyWithKeywords(text: text)
    }
}
