import Testing
import UMCFoundation
@testable import HomeDomain

@Suite("ClassifyScheduleUseCase — 분류 파이프라인 검증")
struct ClassifyScheduleUseCaseTests {

    @Test("캐시 hit 시 ML/키워드 분류 없이 캐시된 카테고리를 즉시 반환한다")
    func cacheHitReturnsImmediately() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = true
        repository.mlResult = .project
        repository.cache["study 세미나"] = .study
        let useCase = ClassifyScheduleUseCase(repository: repository)

        let result = await useCase.execute(title: "Study 세미나")

        #expect(result == .study)
        #expect(repository.classifyWithMLCallCount == 0)
        #expect(repository.classifyWithKeywordsCallCount == 0)
    }

    @Test("제목에 OT 토큰이 있으면 ML 결과보다 강제 규칙(orientation)이 우선한다")
    func forcedRuleOverridesMLResult() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = true
        repository.mlResult = .project
        let useCase = ClassifyScheduleUseCase(repository: repository)

        let result = await useCase.execute(title: "신입 OT 안내")

        #expect(result == .orientation)
        #expect(repository.cache["신입 ot 안내"] == .orientation)
    }

    @Test("모델 미로드 시 ML을 호출하지 않고 키워드 분류로 fallback한다")
    func modelNotLoadedFallsBackToKeywords() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = false
        repository.mlResult = .project
        repository.keywordResult = .meeting
        let useCase = ClassifyScheduleUseCase(repository: repository)

        let result = await useCase.execute(title: "정기 회의")

        #expect(result == .meeting)
        #expect(repository.classifyWithMLCallCount == 0)
        #expect(repository.classifyWithKeywordsCallCount == 1)
    }

    @Test("분류 결과가 정규화된 캐시 키로 저장된다")
    func classificationResultIsCached() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = false
        repository.keywordResult = .hackathon
        let useCase = ClassifyScheduleUseCase(repository: repository)

        _ = await useCase.execute(title: "  해커톤  대회  ")

        #expect(repository.cache["해커톤 대회"] == .hackathon)
    }

    @Test("캐시 키 정규화: 공백/대소문자가 달라도 같은 캐시를 사용한다")
    func cacheKeyNormalizationTrimsCaseAndWhitespace() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = false
        repository.keywordResult = .workshop
        let useCase = ClassifyScheduleUseCase(repository: repository)

        _ = await useCase.execute(title: "MT 워크샵")
        let result = await useCase.execute(title: "  mt   워크샵  ")

        #expect(result == .workshop)
        #expect(repository.classifyWithKeywordsCallCount == 1)
    }

    @Test("빈 제목은 분류 없이 .general을 반환한다")
    func blankTitleReturnsGeneralWithoutClassifying() async {
        let repository = MockScheduleClassifierRepository()
        repository.isModelLoaded = true
        repository.mlResult = .project
        let useCase = ClassifyScheduleUseCase(repository: repository)

        let result = await useCase.execute(title: "   ")

        #expect(result == .general)
        #expect(repository.classifyWithMLCallCount == 0)
        #expect(repository.classifyWithKeywordsCallCount == 0)
        #expect(repository.cache.isEmpty)
    }
}
