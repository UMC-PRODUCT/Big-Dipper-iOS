//
//  ReceivedCardSnapshotCell.swift
//  BusinessCardPresentation
//
//  Created by One on 8/30/26.
//

import SwiftUI
import BusinessCardDomain
import UIKit

/// 명함첩 그리드 한 칸 — 스냅샷이 있으면 3D 렌더 이미지를, 없으면 ``ReceivedCardCell`` 2D
/// 레이아웃을 그린다.
///
/// 폴백이 스피너가 아니라 **완성된 2D 셀**인 것이 이 화면의 핵심이다. 이름·학교·파트·기수·아바타가
/// 전부 들어 있어 굽는 동안에도 정보 손실이 0 이고, 3D 가 영구 실패해도 화면이 성립한다.
/// 스파이크(#1245)가 「첫 카드 렌더 전 로딩 상태 필수」를 조건으로 걸었던 자리다.
struct ReceivedCardSnapshotCell: View {

    // MARK: - Property

    let card: ReceivedCard

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var snapshot: UIImage?

    // MARK: - Constants

    private enum Constants {
        static let crossfade: Double = 0.15
    }

    // MARK: - Init

    /// 메모리 히트를 초깃값으로 넣어 첫 프레임 깜빡임을 없앤다 — 되돌아 스크롤할 때 2D 셀이
    /// 한 프레임 스쳤다가 이미지로 바뀌는 현상을 막는다. NSCache 동기 조회라 마이크로초다.
    @MainActor
    init(card: ReceivedCard) {
        self.card = card
        _snapshot = State(initialValue: BusinessCardSnapshotProvider.cached(for: card))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 폴백이 **항상** 사이징 레이어다. 스냅샷 쪽에 높이 상수 사본을 두면 그 값이
            // ``ReceivedCardCell`` 의 바닥값과 사람 손으로 맞춰져야 하는데, 폴백은 글자가
            // 커지면 늘어나는 반면 상수는 그대로라 Dynamic Type 마다 어긋난다. 셀마다 굽기가
            // 끝나는 시점도 달라서 스크롤 중 행 높이가 제각각 줄어든다.
            ReceivedCardCell(card: card)
                .opacity(showsSnapshot ? .zero : 1)

            if showsSnapshot, let snapshot {
                Image(uiImage: snapshot)
                    .resizable()
                    // 512px 원본을 셀 폭으로 축소하므로 보간을 켜야 얇은 획이 드롭되지 않는다.
                    .interpolation(.high)
                    .scaledToFit()
            }
        }
        // 그림으로 바뀌었다고 VoiceOver 경험이 달라지면 안 된다 — 2D 셀과 같은 문자열이다.
        // 컨테이너 레벨이라 뒤에 숨은 폴백 셀이 같은 내용을 한 번 더 읽는 것도 여기서 막힌다.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .animation(
            reduceMotion ? nil : .easeOut(duration: Constants.crossfade),
            value: showsSnapshot
        )
        // 재교환은 같은 `id` 로 upsert 라 셀 뷰가 살아 있는 채 `profile` 만 바뀐다. 키를 id 로
        // 걸어야 그때 task 가 다시 돌고, 콘텐츠 기반 캐시 키의 자동 무효화가 실제로 발동한다.
        .task(id: BusinessCardSnapshotProvider.key(for: card), priority: .utility) {
            await loadSnapshot()
        }
    }

    // MARK: - Function

    /// 진입 즉시 굽지 않고 정착 지연을 둔다. 플링 중 스쳐 지나가는 셀은 여기서 취소되므로
    /// (`LazyVGrid` 가 뷰를 제거하며 task 를 취소한다) 굽기가 시작조차 하지 않는다 —
    /// 스크롤 프레임에 90ms 짜리 렌더가 실릴 경로가 없다.
    private func loadSnapshot() async {
        // 구운 비트맵은 텍스트 크기 설정을 전혀 따르지 않는다. 접근성 크기에서는 폴백 2D 셀을
        // 그대로 두므로, 보이지도 않을 이미지를 위해 굽기 비용을 태울 이유가 없다.
        guard !dynamicTypeSize.isAccessibilitySize else { return }
        snapshot = BusinessCardSnapshotProvider.cached(for: card)
        guard snapshot == nil else { return }
        try? await Task.sleep(for: BusinessCardSnapshotProvider.Metrics.settleDelay)
        guard !Task.isCancelled else { return }
        snapshot = await BusinessCardSnapshotProvider.snapshot(for: card)
    }

    // MARK: - Computed Property

    /// 접근성 텍스트 크기에서는 스냅샷을 쓰지 않는다 — 비트맵은 Dynamic Type 을 못 따라가서
    /// 이름 11.1pt / 부가정보 7.8pt 로 얼어붙는다. 폴백은 17pt / 13pt 로 설정을 따른다.
    private var showsSnapshot: Bool {
        snapshot != nil && !dynamicTypeSize.isAccessibilitySize
    }

    /// 「홍길동/길동, ○○대학교, iOS 파트, 12기」 — ``ReceivedCardCell`` 과 같은 규칙.
    ///
    /// #1247 이 머지되면 `MyCard` 의 앞면 라벨로 합치는 것이 정리 방향이지만, 지금 그 파일을
    /// 건드리면 같은 줄을 두 PR 이 고치게 된다.
    private var accessibilityLabel: String {
        let nickname = card.profile.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayName = nickname.isEmpty
            ? card.profile.name
            : "\(card.profile.name)/\(nickname)"
        return [
            displayName,
            card.profile.university,
            "\(card.profile.partDisplayName) 파트",
            "\(card.profile.generation)기",
        ].joined(separator: ", ")
    }
}

// MARK: - Preview

#if DEBUG
#Preview("명함첩 스냅샷 그리드") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(spacing: 8), count: 2), spacing: 8) {
            ForEach(BusinessCardPreviewData.receivedCards) { card in
                ReceivedCardSnapshotCell(card: card)
            }
        }
        .padding(16)
    }
}
#endif
