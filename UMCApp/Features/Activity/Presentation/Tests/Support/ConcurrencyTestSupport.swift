//
//  ConcurrencyTestSupport.swift
//  ActivityPresentationTests
//
//  Created by jaewon Lee on 7/19/26.
//

import Foundation

#if DEBUG

/// 조건이 만족될 때까지 MainActor 를 양보하며 대기한다(무한 루프 방지 상한 포함).
///
/// mock 은 실제 I/O 지연이 없어 몇 번의 yield 로 끝난다. 게이트로 suspend 된 요청이
/// mock 호출 기록을 남기거나, fire-and-forget `Task` 가 완료될 때까지 기다리는 용도.
/// 동시성 스위트가 공유하는 test-support 헬퍼로, 파일별 사본을 만들지 않는다.
@MainActor
func drainUntil(maxYields: Int = 10_000, _ condition: () -> Bool) async {
    var yields = 0
    while !condition(), yields < maxYields {
        await Task.yield()
        yields += 1
    }
}

#endif
