import CoreML
import Foundation
import HomeDomain
import UMCFoundation

/// 일정 분류 Repository 구현체.
///
/// CoreML(``ScheduleListClassifierML``) 예측과 키워드 매칭으로 일정 제목을 분류하고, 분류
/// 결과를 `UserDefaults` 기반 캐시에 저장해 재계산을 피한다. 모델/캐시는 초기화 시점에 한 번
/// 로드하며(DIContainer가 resolve 결과를 캐싱하므로 앱 생애주기 동안 1회), 이후 재로드 경로는
/// 없다.
public final class ScheduleClassifierRepository: ScheduleClassifierRepositoryProtocol,
                                                 @unchecked Sendable {

    // MARK: - Property

    private let model: MLModel?
    public let isModelLoaded: Bool

    private let userDefaults: UserDefaults
    private let cacheLock = NSLock()
    private var cache: [String: ScheduleIconCategory]

    // MARK: - Constants

    private enum Constants {
        static let cacheStorageKey = "ScheduleClassifierCache.v5"
    }

    // MARK: - Init

    /// 운영(DI)/테스트 공용 진입점.
    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.cache = Self.loadCacheFromDisk(userDefaults: userDefaults)
        let loadedModel = Self.loadModel()
        self.model = loadedModel
        self.isModelLoaded = loadedModel != nil
    }

    // MARK: - Function

    public func classifyWithML(title: String) -> ScheduleIconCategory? {
        guard let model else { return nil }

        do {
            let input = ScheduleListClassifierMLInput(text: title)
            let prediction = try model.prediction(from: input)
            guard let label = prediction.featureValue(for: "label")?.stringValue else {
                return nil
            }
            return Self.mapMLLabelToCategory(label)
        } catch {
            #if DEBUG
            print(
                "[ScheduleClassifierRepository] classifyWithML 예측 실패: "
                    + error.localizedDescription
            )
            #endif
            return nil
        }
    }

    public func classifyWithKeywords(title: String) -> ScheduleIconCategory {
        let lowercased = title.lowercased()
        for rule in Self.keywordRules
        where rule.keywords.contains(where: { lowercased.contains($0) }) {
            return rule.category
        }
        return .general
    }

    public func getCachedCategory(for cacheKey: String) -> ScheduleIconCategory? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return cache[cacheKey]
    }

    public func cacheCategory(_ category: ScheduleIconCategory, for cacheKey: String) {
        let snapshot: [String: ScheduleIconCategory] = {
            cacheLock.lock()
            defer { cacheLock.unlock() }
            cache[cacheKey] = category
            return cache
        }()
        saveCacheToDisk(snapshot)
    }

    // MARK: - Private Function

    private func saveCacheToDisk(_ cache: [String: ScheduleIconCategory]) {
        let encoded = cache.mapValues(\.rawValue)
        guard let data = try? JSONEncoder().encode(encoded) else { return }
        userDefaults.set(data, forKey: Constants.cacheStorageKey)
    }

    private static func loadCacheFromDisk(
        userDefaults: UserDefaults
    ) -> [String: ScheduleIconCategory] {
        guard
            let data = userDefaults.data(forKey: Constants.cacheStorageKey),
            let decoded = try? JSONDecoder().decode([String: String].self, from: data)
        else {
            return [:]
        }
        return decoded.compactMapValues { rawValue in
            guard
                let category = ScheduleIconCategory(rawValue: rawValue),
                !category.isDeprecated
            else {
                return nil
            }
            return category
        }
    }

    /// CoreML이 생성한 `ScheduleListClassifierML.urlOfModelInThisBundle`은 `Bundle(for:)`로
    /// 자기 코드가 정적 링크된 바이너리(앱/테스트 번들)를 찾는데, HomeData는 staticFramework라
    /// 컴파일된 `.mlmodelc`가 별도 리소스 번들(`Home_HomeData.bundle`)에 담겨 있어 그 경로로는
    /// 찾지 못하고 강제 언래핑에서 크래시한다. Tuist가 생성한 `Bundle.module`로 직접 경로를
    /// 찾아 `init(contentsOf:)`로 우회한다.
    private static func loadModel() -> MLModel? {
        guard
            let modelURL = Bundle.module.url(
                forResource: "ScheduleListClassifierML",
                withExtension: "mlmodelc"
            )
        else {
            #if DEBUG
            print("[ScheduleClassifierRepository] CoreML 모델 리소스를 찾지 못했습니다.")
            #endif
            return nil
        }

        do {
            return try ScheduleListClassifierML(contentsOf: modelURL).model
        } catch {
            #if DEBUG
            print("[ScheduleClassifierRepository] CoreML 모델 로드 실패: \(error.localizedDescription)")
            #endif
            return nil
        }
    }

    /// CoreML 라벨 문자열을 앱 카테고리로 매핑한다.
    ///
    /// 별칭(`fee`/`dues`, `review`/`retrospective`, `celebration`/`after_party`/`after-party`)과
    /// 레거시 테스트 라벨(`testing`/`test`/`qa` → nil, 키워드 분류로 fallback)을 처리한다.
    private static func mapMLLabelToCategory(_ rawLabel: String) -> ScheduleIconCategory? {
        let normalized = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if normalized.isEmpty || normalized == "-" {
            return nil
        }

        switch normalized {
        case "leadership": return .leadership
        case "study": return .study
        case "fee", "dues": return .fee
        case "meeting": return .meeting
        case "networking": return .networking
        case "hackathon": return .hackathon
        case "project": return .project
        case "presentation": return .presentation
        case "workshop": return .workshop
        case "review", "retrospective": return .review
        case "celebration", "after_party", "after-party": return .celebration
        case "orientation": return .orientation
        case "testing", "test", "qa": return nil
        case "general": return .general
        default:
            return ScheduleIconCategory(rawValue: normalized.uppercased())
        }
    }

    /// 키워드 매칭 테이블. 배열 순서가 우선순위이며, 첫 매칭 카테고리를 반환한다.
    private static let keywordRules: [(category: ScheduleIconCategory, keywords: [String])] = [
        (.leadership, ["lt", "리더십", "단체", "임원", "운영진", "파트장"]),
        (.study, ["스터디", "공부", "학습", "강의", "세미나", "교육"]),
        (.fee, ["회비", "참가비", "비용", "납부", "결제", "정산"]),
        (.meeting, ["회의", "미팅", "모임"]),
        (.networking, ["네트워킹", "교류", "친목", "커피챗"]),
        (.hackathon, ["해커톤", "아이디어톤", "메이커톤", "대회"]),
        (.project, ["프로젝트", "개발", "앱", "웹"]),
        (.presentation, ["발표", "컨퍼런스", "프레젠테이션", "pt"]),
        (.workshop, ["mt", "워크샵", "여행", "합숙"]),
        (.review, ["회고", "리뷰", "돌아보기", "피드백"]),
        (.celebration, ["데모데이", "축하", "파티", "수료", "졸업"]),
        (.orientation, ["ot", "오리엔테이션", "환영", "온보딩"]),
    ]
}
