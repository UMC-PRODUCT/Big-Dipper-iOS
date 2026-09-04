//
//  BusinessCardSnapshotProvider.swift
//  BusinessCardPresentation
//
//  Created by One on 8/30/26.
//

import BusinessCardDomain
import Foundation
import Kingfisher
import UIKit
import UMCFoundation

/// 명함첩 그리드용 2D 스냅샷의 단일 진입점 — 키 구성 · 2계층 캐시 · 굽기 오케스트레이션.
///
/// 캐시를 새로 만들지 않고 이미 링크된 Kingfisher `ImageCache` 하나로 끝낸다. NSCache 메모리
/// 계층(cost 상한·메모리 경고 축출·백그라운드 진입 시 비움)·디스크 계층(바이트 상한·만료·마지막
/// 접근 시각 기준 LRU 트리밍)·오프메인 IO·PNG 직렬화가 전부 들어 있어서, 직접 쓰면 이미 있는
/// 것을 다시 만드는 일이 된다.
@MainActor
enum BusinessCardSnapshotProvider {

    // MARK: - Property

    /// 스냅샷 전용 캐시. 이름이 곧 `Library/Caches` 아래 디렉터리라 다른 이미지 캐시와 섞이지
    /// 않는다.
    ///
    /// `Application Support` 가 아니라 `Caches` 인 이유: 스냅샷은 SwiftData 명함첩에서 언제든
    /// 다시 만들 수 있는 **파생물**이고, 재생성 가능한 이미지로 사용자 백업 용량을 먹으면 안 된다.
    nonisolated static let cache: ImageCache = {
        let cache = ImageCache(name: Constants.cacheName)
        cache.memoryStorage.config.totalCostLimit = Metrics.memoryLimit
        cache.diskStorage.config.sizeLimit = UInt(Metrics.diskLimit)
        cache.diskStorage.config.expiration = Metrics.diskExpiration
        return cache
    }()

    /// 이번 프로세스에서 굽기가 **항구적으로** 실패한 키.
    ///
    /// Metal 디바이스가 없거나 템플릿이 깨진 환경에서 셀이 보일 때마다 90ms 를 다시 태우는 걸
    /// 막는다. 디스크에 남기지 않아서 앱을 다시 켜면 한 번 더 시도한다 — 실패를 영구화하지 않는다.
    private static var failedKeys: Set<String> = []

    /// 스냅샷 튜너블. 픽셀 크기는 캐시 키 컴포넌트라 **여기만 고치면 전량 자동 무효화**된다.
    enum Metrics {

        /// 512 × 288 — 카드 비 1.8 에 맞춘 값(512 / 1.8 ≈ 288). 그리드 셀 실측 폭 181pt 기준
        /// 유효 배율 2.83x 라 @3x 기기에서도 흐리지 않고, 정사각 512² 처럼 픽셀의 44% 를
        /// letterbox 여백으로 버리지 않는다. 디코드 메모리는 512 × 288 × 4 = 590KB/장.
        static let snapshotPixelSize = CGSize(width: 512, height: 288)

        /// 12MB ≈ 20장. 2열 그리드 한 화면이 8칸이므로 되돌려 스크롤해도 히트하는 두 화면 반
        /// 분량이다. 장당 크기가 고정이라 cost 상한이 곧 장수 상한이라서 `countLimit` 은 두지 않는다.
        static let memoryLimit = 12 * 1_024 * 1_024

        /// 20MB ≈ 500장 이상(장당 PNG 30~40KB). 초과하면 Kingfisher 가 마지막 접근이 오래된
        /// 것부터 상한 절반까지 지운다 — 자주 여는 명함이 남는다.
        static let diskLimit = 20 * 1_024 * 1_024

        /// 조회로 연장하지 않는 **절대** TTL. `avatarURL` 이 그대로인 채 그 URL 의 사진만 바뀐
        /// 경우는 콘텐츠 키로 못 잡는데, 이 만료가 스테일 상한을 유한하게 만드는 유일한 장치다.
        static let diskExpiration: StorageExpiration = .days(30)

        /// 셀이 화면에 머물러야 굽기가 시작되는 정착 지연. 플링 중 스쳐 지나가는 셀은 이 시간을
        /// 못 넘기고 사라지면서 task 가 취소돼 굽기가 시작조차 안 된다.
        static let settleDelay: Duration = .milliseconds(120)
    }

    private enum Constants {
        static let cacheName = "umc.businesscard.snapshot"
        /// 마지막으로 스냅샷을 구운 계정. **디바이스 스코프**다 —
        /// `AppStorageKey.sessionScopedKeys` 에 넣으면 로그아웃 때 같이 지워져 「이전 소유자」를
        /// 잊어버리고, 그러면 다음 계정이 purge 를 건너뛴다.
        static let cacheOwnerKey = "businessCardSnapshotCacheOwner"
    }

    // MARK: - Function

    /// 메모리 캐시 동기 조회. 셀 `init` 이 첫 프레임 깜빡임을 없애는 데 쓴다.
    ///
    /// NSCache 조회라 스레드 안전하고 마이크로초 단위다. 스크롤 중 새 셀이 만들어져도 프레임
    /// 예산(16.7ms)에 잡히지 않는다 — 스크롤 경로에서 도는 유일한 스냅샷 코드가 이것이다.
    static func cached(for card: ReceivedCard) -> UIImage? {
        cache.retrieveImageInMemoryCache(forKey: key(for: card))
    }

    /// 메모리 → 디스크 → 굽기 순으로 스냅샷을 돌려준다. 실패하면 `nil` 이고 호출부는 2D 셀을
    /// 그대로 둔다 (정보 손실 0).
    ///
    /// - Parameter compose: 카드 엔티티 합성기. 테스트가 스텁을 꽂는 자리다. `nil` 이면
    ///   ``BusinessCardSnapshotRenderer/defaultComposing`` 으로 풀린다 — 여기서 기본값을
    ///   적어 두면 기본 인자가 호출자 격리로 평가돼 Swift 6 언어 모드에서 에러가 된다.
    static func snapshot(
        for card: ReceivedCard,
        compose: BusinessCardEntityComposing? = nil
    ) async -> UIImage? {
        purgeIfOwnerChanged()

        let key = key(for: card)
        guard !failedKeys.contains(key) else { return nil }
        if let hit = cache.retrieveImageInMemoryCache(forKey: key) { return hit }
        if let stored = try? await cache.retrieveImage(
            forKey: key,
            // 만료를 연장하지 않는다 (`Metrics.diskExpiration` 참고).
            options: [.diskCacheAccessExtendingExpiration(.none)]
        ), let image = stored.image {
            return image
        }

        do {
            let image = try await BusinessCardSnapshotRenderer.render(
                card.profile,
                // #1248 이 오면 여기서 `RemoteImageLoader` 로 아바타를 채운다 (설계 §11-2).
                portrait: nil,
                pixelSize: Metrics.snapshotPixelSize,
                compose: compose
            )
            try? await cache.store(image, forKey: key)
            return image
        } catch is CancellationError {
            // 취소는 실패가 아니다 — 셀이 다시 보이면 다시 굽는다.
            return nil
        } catch {
            failedKeys.insert(key)
            return nil
        }
    }

    /// 계정이 바뀌었으면 캐시를 통째로 비운다.
    ///
    /// 화면에 남의 명함이 뜨지는 않는다 — 명함첩 목록 자체가 `ownerMemberId` 로 격리되고(#1217)
    /// 그리드는 그 목록에 있는 카드만 조회한다. 지워야 하는 건 **디스크에 남는 바이트**다.
    /// 스냅샷 이미지에는 이전 사용자가 받은 사람의 이름·학교·파트가 그려져 있다.
    ///
    /// 로그아웃 순간이 아니라 다음 그리드 진입 시 지운다. 즉시 삭제하려면 `NetworkClient.logout()`
    /// 에 훅을 걸어야 하는데 CoreNetwork → Feature 역방향 의존이 생긴다 — 값싸지 않다.
    ///
    /// - Returns: 실제로 비웠으면 `true`.
    @discardableResult
    static func purgeIfOwnerChanged(
        owner: String?,
        in defaults: UserDefaults,
        cache: ImageCache
    ) -> Bool {
        let current = owner ?? ""
        let previous = defaults.string(forKey: Constants.cacheOwnerKey)
        guard previous != current else { return false }

        defaults.set(current, forKey: Constants.cacheOwnerKey)
        // 저장값이 없으면 「계정이 바뀐 것」이 아니라 「이 기기에서 처음 들어온 것」이다.
        // 소유자만 기록하고 넘어가지 않으면 신규 설치마다 빈 캐시를 비우는 IO 가 한 번 돈다.
        guard previous != nil else { return false }
        cache.clearMemoryCache()
        cache.clearDiskCache()
        failedKeys.removeAll()
        return true
    }

    /// 카드 → 캐시 키. 앞면에 찍히는 필드만 지나는 유일한 경로라 테스트가 여기에 단정을 건다.
    static func key(for card: ReceivedCard) -> String {
        Key(card: card.profile, pixelSize: Metrics.snapshotPixelSize).string
    }

    // MARK: - Private

    private static func purgeIfOwnerChanged() {
        purgeIfOwnerChanged(
            owner: AppStorageKey.memberIdString(),
            in: .standard,
            cache: cache
        )
    }
}

// MARK: - Cache Key

extension BusinessCardSnapshotProvider {

    /// 스냅샷 캐시 키 — **그려질 픽셀을 결정하는 입력의 전체 집합**이다.
    ///
    /// 입력이 하나라도 달라지면 키가 달라지고, 달라진 키는 정의상 캐시 미스라 새로 굽는다.
    /// 그래서 「무효화」라는 별도 동작·플래그·버전 테이블이 없다. 옛 이미지는 참조되지 않은 채
    /// 남았다가 TTL·LRU 로 사라진다. 부수 효과로 같은 픽셀을 만드는 두 카드는 파일을 공유한다.
    ///
    /// `Hasher`/`hashValue` 를 쓰지 않는다 — 프로세스마다 시드가 달라 디스크 키로 못 쓴다.
    ///
    /// 앞면에 찍히지 않는 값(`exchangedAt`·`exchangeContext`·`exchangeMethod`·`ReceivedCard.id`·
    /// 링크 4종)은 넣지 않는다. 넣으면 의미 없는 재생성만 는다.
    struct Key {

        // MARK: - Property

        /// `U+001F`(Unit Separator). 사용자 입력에 절대 나타나지 않는 제어문자라 필드 경계가
        /// 모호해지지 않고(`"김유"+"엠"` ≠ `"김"+"유엠"`) 이스케이프도 필요 없다.
        private static let separator = "\u{1F}"

        /// 앱 버전(+디버그 빌드 지문). 렌더러·템플릿·레이아웃 변경은 반드시 릴리스를 타므로,
        /// 버전을 키에 넣으면 사람이 상수를 올리는 걸 잊어도 전량 자동 무효화된다.
        private static let buildComponents: [String] = {
            let info = Bundle.main.infoDictionary
            let version = info?["CFBundleShortVersionString"] as? String ?? "0"
            let build = info?["CFBundleVersion"] as? String ?? "0"
            #if DEBUG
            // 디버그에서는 릴리스 번호가 오르지 않는다 — 실행 파일 수정 시각으로 재컴파일을
            // 잡아야 템플릿을 만져도 옛 이미지가 남는 함정이 없다.
            let modified = try? Bundle.main.executableURL?
                .resourceValues(forKeys: [.contentModificationDateKey])
                .contentModificationDate
            let fingerprint = (modified ?? nil).map { "\(Int($0.timeIntervalSince1970))" } ?? "0"
            return ["\(version)+\(build)", fingerprint]
            #else
            return ["\(version)+\(build)"]
            #endif
        }()

        private let components: [String]

        // MARK: - Init

        /// - Note: `displayName` 같은 파생 값이 아니라 `name`·`nickname` 원본 필드를 쓴다.
        ///   그 computed property 를 #1247 은 Presentation 에, #1248 은 Domain 에 각각 추가해서
        ///   어느 쪽이 먼저 머지되든 셋째 사본을 만들지 않으려는 것이다.
        init(card: MyCard, pixelSize: CGSize) {
            components = Self.buildComponents + [
                "\(Int(pixelSize.width))x\(Int(pixelSize.height))",
                // 지금 구워지는 픽셀은 색상 스킴과 무관하다(시드가 RGB 리터럴, 텍스트가 단색)
                // — 즉 **잠복 상태**다. 다만 #1248 템플릿이 DS 토큰을 하나라도 쓰는 순간
                // `UIColor(Color)` 해석이 굽는 시점 트레잇으로 고정되고, 그 결과가 디스크에
                // 30일 남는다. 앱 버전으로만 무효화되니 릴리스 전까지 자가 치유되지 않는다.
                // 한 줄 넣는 비용이 그때 디버깅하는 비용보다 싸다.
                "\(UITraitCollection.current.userInterfaceStyle.rawValue)",
                card.memberId,
                card.name,
                card.nickname,
                // `part`(열거형)가 아니라 이 값이어야 우리가 못 읽은 파트(`partRaw`)가 구분된다.
                card.partAPIValue,
                // 핵심 규칙 #2 — 서버 정수는 Int 변환 없이 String 그대로 키에 넣는다.
                card.generation,
                card.university,
                card.avatarURL ?? "",
            ]
        }

        // MARK: - Computed Property

        var string: String {
            components.joined(separator: Self.separator)
        }
    }
}
