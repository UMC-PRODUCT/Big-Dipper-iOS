//
//  DIContainer+StubSession.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import AuthDomain
import CommunityData
import CommunityDomain
import CoreDI
import CoreDomain
import HomeDomain
import NoticeDomain
import os.log

extension DIContainer {

    /// stub 세션용 Repository 오버라이드를 등록한다.
    ///
    /// `DIContainer.register`는 마지막 등록이 이기므로(last-wins), 실제 의존성 등록이 모두
    /// 끝난 뒤 · 최초 `resolve` 이전(= `UMCAppApp.init()` 내부)에 호출해야 한다.
    /// Repository 계층만 교체하므로 UseCase/도메인 로직(승인 판정, 프로필 동기화,
    /// 최근 공지 5건 절삭 등)은 실물 그대로 동작한다.
    func registerStubSessionOverrides() {
        register(AuthRepositoryProtocol.self) {
            StubAuthRepository()
        }
        register(MemberProfileRepositoryProtocol.self) {
            StubMemberProfileRepository()
        }
        register(HomeRepositoryProtocol.self) {
            StubHomeRepository()
        }
        register(ScheduleRepositoryProtocol.self) {
            StubScheduleRepository()
        }
        register(ScheduleCapabilitiesRepositoryProtocol.self) {
            StubScheduleCapabilitiesRepository()
        }
        register(NoticeRepositoryProtocol.self) {
            StubNoticeRepository()
        }
        register(StudyRepositoryProtocol.self) {
            StubStudyRepository()
        }
        register(MemberRepositoryProtocol.self) {
            StubMemberRepository()
        }
        register(ChallengerAttendanceRepositoryProtocol.self) {
            StubAttendanceRepository()
        }
        register(OperatorAttendanceRepositoryProtocol.self) {
            StubAttendanceRepository()
        }
        // 실시간(STOMP)은 그대로 둔다 — 교체하면 재연결·백필 경로를 stub 모드에서 못 밟는다.
        register(CommunityThreadRepositoryProtocol.self) {
            MockCommunityThreadRepository()
        }

        Logger(subsystem: "UMCApp", category: "StubSession")
            .notice("""
                Stub 세션 모드 활성화 — 인증·홈·공지·스터디·멤버·출석·커뮤니티 데이터가 픽스처로 \
                대체됩니다. 커뮤니티 실시간(STOMP)만 실서버라 메시지 전송은 15초 뒤 실패합니다.
                """)
    }
}
#endif
