//
//  DIContainer+MemberProfile.swift
//  UMCApp
//
//  Created by euijjang97 on 7/10/26.
//

import CoreDI
import CoreDomain
import CoreNetwork

extension DIContainer {
    /// 정본 프로필 조회 파이프라인을 등록한다.
    ///
    /// `MemberProfileRepositoryProtocol`은 세션 단위 캐싱 데코레이터(``CachedMemberProfileRepository``)로
    /// 등록된다 — `resolve()`가 인스턴스를 캐싱하므로(싱글턴 동작), 캐시 수명도 자연히 세션(로그인~로그아웃)
    /// 단위가 된다. 소비부(Auth/Home/MyPage)는 프로토콜만 바라보므로 캐싱 도입이 계약에 영향을 주지 않는다.
    func registerMemberProfileDependencies() {
        register(MemberProfileRepositoryProtocol.self) {
            CachedMemberProfileRepository(
                remote: MemberProfileRepository(adapter: self.resolve(MoyaNetworkAdapter.self))
            )
        }
        register(FetchMemberProfileUseCaseProtocol.self) {
            FetchMemberProfileUseCase(
                repository: self.resolve(MemberProfileRepositoryProtocol.self)
            )
        }
    }
}
