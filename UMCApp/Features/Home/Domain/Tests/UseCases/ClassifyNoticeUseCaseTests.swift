import Testing
@testable import HomeDomain

@Suite("ClassifyNoticeUseCase — 알림 분류 파이프라인 검증")
struct ClassifyNoticeUseCaseTests {

    @Test("모델이 로드되고 예측에 성공하면 ML 결과를 반환한다")
    func modelLoadedReturnsMLResult() {
        let repository = MockNoticeClassifierRepository()
        repository.isModelLoaded = true
        repository.mlResult = .success
        repository.keywordResult = .warning
        let useCase = ClassifyNoticeUseCase(repository: repository)

        let result = useCase.execute(title: "합격 안내", content: "축하합니다")

        #expect(result == .success)
        #expect(repository.classifyWithKeywordsCallCount == 0)
    }

    @Test("모델 미로드 시 ML을 호출하지 않고 키워드 분류로 fallback한다")
    func modelNotLoadedFallsBackToKeywords() {
        let repository = MockNoticeClassifierRepository()
        repository.isModelLoaded = false
        repository.mlResult = .success
        repository.keywordResult = .warning
        let useCase = ClassifyNoticeUseCase(repository: repository)

        let result = useCase.execute(title: "결석 경고", content: "1회 누적")

        #expect(result == .warning)
        #expect(repository.classifyWithMLCallCount == 0)
        #expect(repository.classifyWithKeywordsCallCount == 1)
    }

    @Test("모델은 로드됐지만 예측이 실패하면 키워드 분류로 fallback한다")
    func mlPredictionFailureFallsBackToKeywords() {
        let repository = MockNoticeClassifierRepository()
        repository.isModelLoaded = true
        repository.mlResult = nil
        repository.keywordResult = .error
        let useCase = ClassifyNoticeUseCase(repository: repository)

        let result = useCase.execute(title: "탈락 통보", content: "다음 기회에")

        #expect(result == .error)
        #expect(repository.classifyWithMLCallCount == 1)
        #expect(repository.classifyWithKeywordsCallCount == 1)
    }

    @Test("제목과 본문을 공백으로 이어 붙여 분류기에 전달한다")
    func titleAndContentAreJoined() {
        let repository = MockNoticeClassifierRepository()
        let useCase = ClassifyNoticeUseCase(repository: repository)

        _ = useCase.execute(title: "제목", content: "내용")

        #expect(repository.receivedText == "제목 내용")
    }
}
