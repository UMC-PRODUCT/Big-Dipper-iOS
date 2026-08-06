import CoreML
import Foundation
import HomeDomain

/// 알림 분류 Repository 구현체.
///
/// CoreML(``NoticeClassifierML``) 예측과 키워드 매칭으로 푸시 알림 텍스트를 분류한다. 모델은
/// 초기화 시점에 한 번 로드하며(DIContainer가 resolve 결과를 캐싱하므로 앱 생애주기 동안 1회),
/// 이후 재로드 경로는 없다.
public final class NoticeClassifierRepository: NoticeClassifierRepositoryProtocol,
                                               @unchecked Sendable {

    // MARK: - Property

    private let model: MLModel?
    public let isModelLoaded: Bool

    // MARK: - Init

    /// 운영(DI)/테스트 공용 진입점.
    public init() {
        let loadedModel = Self.loadModel()
        self.model = loadedModel
        self.isModelLoaded = loadedModel != nil
    }

    // MARK: - Function

    public func classifyWithML(text: String) -> NoticeAlarmType? {
        guard let model else { return nil }

        do {
            let input = NoticeClassifierMLInput(text: text)
            let prediction = try model.prediction(from: input)
            guard let label = prediction.featureValue(for: "label")?.stringValue else {
                return nil
            }
            return NoticeAlarmType(rawValue: label)
        } catch {
            #if DEBUG
            print(
                "[NoticeClassifierRepository] classifyWithML 예측 실패: "
                    + error.localizedDescription
            )
            #endif
            return nil
        }
    }

    public func classifyWithKeywords(text: String) -> NoticeAlarmType {
        let lowercased = text.lowercased()

        // 성공 키워드가 있어도 부정 키워드가 함께 있으면 실패로 본다 ("제출 실패" 등).
        if Self.successKeywords.contains(where: lowercased.contains) {
            return Self.errorKeywords.contains(where: lowercased.contains) ? .error : .success
        }
        if Self.errorKeywords.contains(where: lowercased.contains) {
            return .error
        }
        if Self.warningKeywords.contains(where: lowercased.contains) {
            return .warning
        }
        return .info
    }

    // MARK: - Private Function

    /// CoreML이 생성한 `NoticeClassifierML.urlOfModelInThisBundle`은 `Bundle(for:)`로 자기 코드가
    /// 정적 링크된 바이너리(앱/테스트 번들)를 찾는데, HomeData는 staticFramework라 컴파일된
    /// `.mlmodelc`가 별도 리소스 번들(`Home_HomeData.bundle`)에 담겨 있어 그 경로로는 찾지 못하고
    /// 강제 언래핑에서 크래시한다. Tuist가 생성한 `Bundle.module`로 직접 경로를 찾아
    /// `init(contentsOf:)`로 우회한다 (``ScheduleClassifierRepository`` 와 동일 패턴).
    private static func loadModel() -> MLModel? {
        guard
            let modelURL = Bundle.module.url(
                forResource: "NoticeClassifierML",
                withExtension: "mlmodelc"
            )
        else {
            #if DEBUG
            print("[NoticeClassifierRepository] CoreML 모델 리소스를 찾지 못했습니다.")
            #endif
            return nil
        }

        do {
            return try NoticeClassifierML(contentsOf: modelURL).model
        } catch {
            #if DEBUG
            print("[NoticeClassifierRepository] CoreML 모델 로드 실패: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    // MARK: - Constants

    private static let successKeywords = [
        "완료", "성공", "승인", "등록", "인증", "제출", "저장", "예약", "송금", "업로드",
        "합격", "확정", "선발",
    ]

    private static let errorKeywords = [
        "거부", "불합격", "반려", "탈락", "제외", "거절", "불가", "미달", "박탈", "실패",
    ]

    private static let warningKeywords = [
        "지각", "경고", "주의", "임박", "마감", "기한", "부족", "확인", "필요", "권장",
        "결석", "지연",
    ]
}
