//
//  BusinessCardSnapshotTests.swift
//  BusinessCardPresentationTests
//
//  Created by One on 8/30/26.
//

import CoreGraphics
import Foundation
import Kingfisher
import RealityKit
import Testing
import UIKit
import BusinessCardDomain
import UMCFoundation
@testable import BusinessCardPresentation

/// 명함첩 그리드 2D 스냅샷(#1249)의 회귀 + 측정 러너.
///
/// 단정하는 것은 **깨지면 기능이 무너지는 것**뿐이다 — 키가 흔들리지 않을 것, 픽셀에 찍히는 값이
/// 바뀌면 키가 갈릴 것, 렌더가 빈 화면이 아닐 것, 실패가 무한 재시도로 번지지 않을 것.
/// 시간·메모리 수치는 로그(`SNAPSHOT#1249`)로 남겨 PR 본문의 근거로 옮긴다.
///
/// 스파이크 스위트와 같은 이유로 `.serialized` 다 — 메모리 증가분이 프로세스 전역
/// `phys_footprint` 차이라서 다른 테스트가 동시에 RealityKit 을 만지면 수치가 오염된다.
///
/// 실행: `cd UMCApp && make test SCHEME=BusinessCardPresentation`
@MainActor
@Suite("명함첩 스냅샷 — 캐시 키·2계층 캐시·굽기 비용", .serialized)
struct BusinessCardSnapshotTests {

    // MARK: - 캐시 키

    @Test("같은 카드는 몇 번을 물어도 같은 키를 낸다")
    func keyIsStable() {
        let profile = makeProfile()

        let first = key(of: profile)
        let second = key(of: profile)

        // `Hasher` 를 쓰면 프로세스마다 시드가 달라 이 단정이 프로세스 간에 깨진다.
        // 디스크 캐시 키로 못 쓴다는 뜻이라, 문자열 구성을 지키는 회귀로 남긴다.
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test("앞면 픽셀을 바꾸는 값이 하나라도 다르면 키가 갈린다")
    func keyChangesWithEveryRenderedField() {
        let base = key(of: makeProfile())

        let variants: [(String, String)] = [
            ("memberId", key(of: makeProfile(memberId: "77"))),
            ("name", key(of: makeProfile(name: "박고은"))),
            ("nickname", key(of: makeProfile(nickname: "고은비"))),
            ("partAPIValue", key(of: makeProfile(part: .pm))),
            ("partRaw", key(of: makeProfile(partRaw: "GRAPHICS"))),
            ("generation", key(of: makeProfile(generation: "13"))),
            ("university", key(of: makeProfile(university: "고려대학교"))),
            ("avatarURL", key(of: makeProfile(avatarURL: "https://umc.dev/a.png"))),
            ("pixelSize", key(of: makeProfile(), pixelSize: CGSize(width: 256, height: 144))),
        ]

        for (field, variant) in variants {
            #expect(variant != base, "\(field) 를 바꿨는데 키가 같다 — 옛 스냅샷이 그대로 뜬다")
        }
        #expect(Set(variants.map(\.1)).count == variants.count)
    }

    @Test("앞면에 찍히지 않는 값만 다르면 같은 키를 낸다")
    func keyIgnoresFieldsThatNeverReachThePixels() {
        let profile = makeProfile()
        let card = ReceivedCard(
            id: "exchange-1",
            profile: profile,
            exchangedAt: Date(timeIntervalSince1970: 0),
            exchangeContext: "OT에서 교환",
            exchangeMethod: .qrLink
        )
        let sameProfileDifferentExchange = ReceivedCard(
            id: "exchange-2",
            profile: profile,
            exchangedAt: Date(timeIntervalSince1970: 1_700_000_000),
            exchangeContext: nil,
            exchangeMethod: .nearby
        )

        // 교환 이력은 그림에 남지 않는다. 키에 넣으면 의미 없는 재생성만 는다.
        #expect(
            BusinessCardSnapshotProvider.key(for: card)
                == BusinessCardSnapshotProvider.key(for: sameProfileDifferentExchange)
        )
    }

    @Test("필드 경계가 애매한 값도 서로 다른 키를 낸다")
    func keySeparatorPreventsFieldCollision() {
        let former = key(of: makeProfile(name: "김유", nickname: "엠"))
        let latter = key(of: makeProfile(name: "김", nickname: "유엠"))

        // 구분자가 없거나 사용자가 입력할 수 있는 문자였다면 둘 다 "김유엠" 으로 뭉개진다.
        #expect(former != latter)
    }

    // MARK: - 캐시

    @Test("캐시에 넣은 스냅샷을 같은 키로 되찾는다")
    func cacheRoundTrip() async throws {
        let cache = makeTemporaryCache()
        defer { discard(cache) }
        let image = makeImage(seed: 0)

        try await cache.store(image, forKey: "roundtrip")
        cache.clearMemoryCache()
        let restored = try await cache.retrieveImage(forKey: "roundtrip")

        #expect(restored.image?.size == image.size)
        #expect(restored.cacheType == .disk)
    }

    @Test("디스크 상한을 넘기면 마지막 접근이 오래된 것부터 지워진다")
    func diskStorageTrimsToLimit() async throws {
        let cache = makeTemporaryCache()
        defer { discard(cache) }
        for index in 0..<trimmedCardCount {
            try await cache.store(makeImage(seed: index), forKey: "trim-\(index)")
        }

        let full = try await cache.diskStorageSize
        cache.diskStorage.config.sizeLimit = full / 2
        _ = try cache.diskStorage.removeSizeExceededValues()
        let trimmed = try await cache.diskStorageSize

        #expect(full > .zero)
        #expect(trimmed <= full / 2)
        // 상한 초과는 전량 삭제가 아니라 트리밍이다 — 자주 여는 명함이 남아야 한다.
        #expect(trimmed > .zero)
    }

    @Test("스냅샷 캐시가 설계한 상한·만료로 설정돼 있다")
    func cacheIsConfiguredAsDesigned() {
        let cache = BusinessCardSnapshotProvider.cache

        // NSCache 축출 시점은 OS 재량이라 「몇 장째에 빠지는지」는 단정하지 않는다.
        // 대신 상한이 설계값에서 조용히 흘러내리지 않는 것을 지킨다 (실제 점유는 ⑥ 측정).
        #expect(cache.memoryStorage.config.totalCostLimit
            == BusinessCardSnapshotProvider.Metrics.memoryLimit)
        #expect(cache.diskStorage.config.sizeLimit
            == UInt(BusinessCardSnapshotProvider.Metrics.diskLimit))
        // `StorageExpiration` 은 Equatable 이 아니라 패턴 매칭으로 본다.
        let expiresInThirtyDays: Bool
        if case .days(30) = cache.diskStorage.config.expiration {
            expiresInThirtyDays = true
        } else {
            expiresInThirtyDays = false
        }
        #expect(expiresInThirtyDays)
        // 재생성 가능한 파생물이라 백업 대상(`Application Support`)에 두지 않는다.
        #expect(cache.diskStorage.directoryURL.path.contains("Caches"))
    }

    @Test("계정이 바뀌면 디스크에 남은 스냅샷을 통째로 지운다")
    func accountSwitchPurgesCache() async throws {
        let suiteName = "snapshot.owner.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { UserDefaults.standard.removePersistentDomain(forName: suiteName) }
        let cache = makeTemporaryCache()
        defer { discard(cache) }

        try await cache.store(makeImage(seed: 0), forKey: "owned")
        let firstEntry = purge(owner: "42", in: defaults, cache: cache)
        let sameOwner = purge(owner: "42", in: defaults, cache: cache)
        // `clearDiskCache` 와 크기 계산이 같은 직렬 ioQueue 를 타므로 순서가 보장된다.
        let afterFirstEntry = try await cache.diskStorageSize

        let switched = purge(owner: "77", in: defaults, cache: cache)
        let remaining = try await cache.diskStorageSize

        // 저장된 소유자가 없는 것은 「계정이 바뀐 것」이 아니라 「최초 진입」이다.
        #expect(!firstEntry, "최초 진입인데 비웠다고 답했다 — 신규 설치마다 헛된 IO 가 돈다")
        #expect(afterFirstEntry > .zero, "최초 진입에서 캐시를 지웠다")
        #expect(!sameOwner, "같은 계정인데 캐시를 비웠다 — 진입할 때마다 전량 재굽기가 된다")
        #expect(switched)
        #expect(remaining == .zero)
    }

    // MARK: - 굽기

    @Test("스냅샷이 512×288 로 나오고 빈 화면이 아니다")
    func renderProducesVisibleCard() async throws {
        let card = makeProfile()
        let size = BusinessCardSnapshotProvider.Metrics.snapshotPixelSize

        let (cold, image) = try await measure {
            try await BusinessCardSnapshotRenderer.render(card, portrait: nil, pixelSize: size)
        }
        // 같은 카드를 다시 구우면 텍스트 메시가 재사용돼 실제보다 빠르게 나온다 —
        // 그리드가 겪는 것은 「매번 다른 카드」라 웜 측정도 다른 프로필로 잰다.
        let (warm, _) = try await measure {
            try await BusinessCardSnapshotRenderer.render(
                makeProfile(name: "박고은", nickname: "고은비", part: .pm),
                portrait: nil,
                pixelSize: size
            )
        }
        let opaque = try opaquePixelRatio(of: image)

        report("""
            ① 첫 굽기 \(cold.decimals(1))ms (RealityKit 초기화 포함 · 같은 프로세스의 \
            스파이크 스위트가 먼저 돌면 이미 웜이다)
            """)
        report("""
            ② 웜 1장(다른 카드) 512×288 \(warm.decimals(1))ms · \
            불투명 픽셀 \((opaque * 100).decimals(1))%
            """)

        #expect(image.size == size)
        #expect(opaque > 0.01, "렌더 결과가 사실상 빈 화면 — 그리드가 폴백만 그리게 된다")
    }

    @Test("그리드 20장 굽기 총비용과 메모리 증가분을 기록한다")
    func gridBakeCost() async throws {
        let cards = (0..<gridCardCount).map(gridCard(index:))
        let before = BusinessCard3DSpike.memoryFootprint()

        let (elapsed, images) = try await measure {
            var baked: [UIImage] = []
            for card in cards {
                baked.append(try #require(await BusinessCardSnapshotProvider.snapshot(for: card)))
            }
            return baked
        }
        let after = BusinessCard3DSpike.memoryFootprint()

        report("""
            ③ 20장 배치 총 \(elapsed.decimals(1))ms (장당 \
            \((elapsed / Double(gridCardCount)).decimals(1))ms)
            """)
        report("⑥ 20장 저장 후 메모리 증가 \((after - before) / 1_024)KB (상한 12MB)")

        #expect(images.count == gridCardCount)
    }

    @Test("메모리 히트와 디스크 히트 비용을 기록한다")
    func cacheHitCost() async throws {
        let card = gridCard(index: hitProbeIndex)
        _ = try #require(await BusinessCardSnapshotProvider.snapshot(for: card))

        _ = try #require(BusinessCardSnapshotProvider.cached(for: card))
        let (memoryTotal, _) = BusinessCard3DSpike.measure {
            for _ in 0..<memoryHitRepeats {
                _ = BusinessCardSnapshotProvider.cached(for: card)
            }
        }

        // 메모리를 비우면 남는 경로는 디스크뿐이다. 합성기가 무조건 던지므로, 이미지가 돌아왔다면
        // 다시 구운 게 아니라 디스크에서 읽었다는 뜻이다.
        BusinessCardSnapshotProvider.cache.clearMemoryCache()
        let (diskElapsed, restored) = await measure {
            await BusinessCardSnapshotProvider.snapshot(for: card) { _, _ in
                throw StubComposeError.refused
            }
        }

        let averageMicroseconds = memoryTotal * 1_000 / Double(memoryHitRepeats)
        report("""
            ④ 메모리 히트 \(memoryHitRepeats)회 평균 \(averageMicroseconds.decimals(2))µs \
            (프레임 예산 16.7ms 대비 \((16.7 * 1_000 / averageMicroseconds).decimals(0))배 여유)
            """)
        report("⑤ 디스크 히트 1장 \(diskElapsed.decimals(2))ms")

        #expect(restored != nil, "디스크에 저장되지 않았다 — 앱 재시작마다 전량 재굽기가 된다")
    }

    @Test("합성이 실패하면 폴백으로 두고 같은 카드를 다시 굽지 않는다")
    func permanentFailureIsRememberedForTheProcess() async throws {
        let card = gridCard(index: failureProbeIndex)
        var composeCalls = 0
        let failing: BusinessCardEntityComposing = { _, _ in
            composeCalls += 1
            throw StubComposeError.refused
        }

        let first = await BusinessCardSnapshotProvider.snapshot(for: card, compose: failing)
        let second = await BusinessCardSnapshotProvider.snapshot(for: card, compose: failing)

        #expect(first == nil)
        #expect(second == nil)
        // 항구적 실패(Metal 없음 등)에서 셀이 보일 때마다 렌더 비용을 다시 태우면 안 된다.
        #expect(composeCalls == 1)
    }

    // MARK: - Private

    /// 이슈 완료 조건의 「20장 이상 그리드」.
    private let gridCardCount = 20
    /// 디스크 트리밍 표본 수. 상한을 총량의 절반으로 낮췄을 때 남는 장이 있어야 LRU 다.
    private let trimmedCardCount = 6
    /// 프레임 예산 대비 자릿수를 보려면 단발 측정으로는 노이즈에 묻힌다.
    private let memoryHitRepeats = 1_000
    /// 굽기 측정용 카드와 키가 겹치지 않게 그리드 범위 밖 번호를 쓴다.
    private let hitProbeIndex = 100
    private let failureProbeIndex = 200
    /// 실행마다 다른 키를 만든다. 디스크 캐시는 시뮬레이터 컨테이너에 남아서, 고정 키로 재면
    /// 두 번째 실행부터 「굽기」가 아니라 디스크 히트를 재게 된다 (실측 6.2ms → 굽기 아님).
    private let runSalt = UUID().uuidString

    private enum StubComposeError: Error {
        case refused
    }

    private func key(
        of profile: MyCard,
        pixelSize: CGSize = BusinessCardSnapshotProvider.Metrics.snapshotPixelSize
    ) -> String {
        BusinessCardSnapshotProvider.Key(card: profile, pixelSize: pixelSize).string
    }

    private func purge(owner: String, in defaults: UserDefaults, cache: ImageCache) -> Bool {
        BusinessCardSnapshotProvider.purgeIfOwnerChanged(
            owner: owner,
            in: defaults,
            cache: cache
        )
    }

    /// 필드 하나만 갈아 끼운 변형을 만들기 위한 픽스처. 기본값은 프리뷰 시드와 같은 사람이다.
    private func makeProfile(
        memberId: String = "42",
        name: String = "김유엠",
        nickname: String = "유엠디",
        part: UMCPartType = .front(type: .ios),
        partRaw: String? = nil,
        generation: String = "12",
        university: String = "한양대학교",
        avatarURL: String? = nil
    ) -> MyCard {
        MyCard(
            memberId: memberId,
            name: name,
            nickname: nickname,
            part: part,
            generation: generation,
            university: university,
            email: nil,
            github: nil,
            linkedIn: nil,
            blog: nil,
            avatarURL: avatarURL,
            partRaw: partRaw
        )
    }

    /// 굽기 측정용 카드. 파트·이름이 섞이도록 프리뷰 시드를 돌려 쓰되 `memberId` 로 키를
    /// 갈라 놓는다 — 같은 키가 섞이면 미스여야 할 자리가 캐시 히트로 새 버린다.
    private func gridCard(index: Int) -> ReceivedCard {
        let seeds = BusinessCardPreviewData.receivedCards
        let seed = seeds[index % seeds.count].profile
        return ReceivedCard(
            id: "snapshot-probe-\(index)",
            profile: makeProfile(
                memberId: "snapshot-probe-\(runSalt)-\(index)",
                name: seed.name,
                nickname: seed.nickname,
                part: seed.part,
                generation: seed.generation,
                university: seed.university
            ),
            exchangedAt: BusinessCardPreviewData.referenceDate,
            exchangeContext: nil
        )
    }

    private func makeTemporaryCache() -> ImageCache {
        ImageCache(name: "test.businesscard.snapshot.\(UUID().uuidString)")
    }

    /// 테스트가 끝나면 디스크에 남기지 않는다. 완료 핸들러 버전이라 `defer` 에서 부를 수 있다.
    private func discard(_ cache: ImageCache) {
        cache.clearMemoryCache()
        cache.clearDiskCache(completion: nil)
    }

    /// 스케일 1 로 그린다 — 포인트와 픽셀이 같아야 PNG 왕복 후 크기 비교가 성립한다.
    private func makeImage(seed: Int) -> UIImage {
        let size = BusinessCardSnapshotProvider.Metrics.snapshotPixelSize
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(hue: CGFloat(seed % 10) / 10, saturation: 1, brightness: 1, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func measure<Value>(
        _ body: () async throws -> Value
    ) async rethrows -> (milliseconds: Double, value: Value) {
        let started = ContinuousClock.now
        let value = try await body()
        return (started.duration(to: .now).milliseconds, value)
    }

    /// 알파가 실제로 칠해진 픽셀 비율. 0 에 가까우면 렌더가 아무것도 안 그린 것이다.
    private func opaquePixelRatio(of image: UIImage) throws -> Double {
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var pixels = [UInt8](repeating: .zero, count: width * height * 4)
        let context = try #require(
            CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        )
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        let opaque = stride(from: 3, to: pixels.count, by: 4).reduce(into: 0) { count, index in
            if pixels[index] > 8 { count += 1 }
        }
        return Double(opaque) / Double(width * height)
    }

    /// 측정치는 실패가 아니라 산출물이므로 로그로 남긴다. PR 본문의 표가 이 줄들이다.
    private func report(_ line: String) {
        print("SNAPSHOT#1249 \(line)")
    }
}

// MARK: - Test Helpers

private extension BinaryFloatingPoint {

    /// 로그 표에 찍을 고정 소수 문자열.
    func decimals(_ fractionDigits: Int) -> String {
        String(format: "%.\(fractionDigits)f", Double(self))
    }
}
