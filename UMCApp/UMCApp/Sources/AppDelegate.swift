//
//  AppDelegate.swift
//  UMCApp
//

import CoreDI
import FirebaseMessaging
import HomeDomain
import SwiftData
import UIKit
import UMCFoundation
import UserNotifications
import os.log

/// 푸시 알림 수신과 FCM 토큰 동기화를 담당하는 AppDelegate.
///
/// 수신한 푸시는 ``NoticeHistoryData`` 로 저장돼 알림 보관함(`NoticeAlarmView`)에 노출되고,
/// FCM 토큰은 로그인 멤버와 짝지어 서버에 등록된다.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    // MARK: - Property

    private var container: DIContainer?
    private var modelContext: ModelContext?
    private var deepLinkStore: DeepLinkStore?
    /// 직전 업로드 실패 조합. 같은 (멤버, 토큰)으로 매번 재시도하지 않도록 기억한다.
    private var lastFailedFCMUpload: (memberId: Int, token: String)?
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "UMCApp",
        category: "Push"
    )

    // MARK: - Constants

    private enum Constants {
        static let fallbackTitle: String = "알림"
        static let authorizationOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
    }

    // MARK: - Function

    /// DIContainer·ModelContext·DeepLinkStore를 주입하고 FCM 토큰 동기화를 시도한다.
    ///
    /// `UMCAppApp`의 루트 뷰 `task`에서 호출된다. 그 전에 도착한 토큰은 UserDefaults에만
    /// 저장돼 있다가 이 시점의 동기화로 업로드된다.
    func configure(
        container: DIContainer,
        modelContext: ModelContext,
        deepLinkStore: DeepLinkStore
    ) {
        self.container = container
        self.modelContext = modelContext
        self.deepLinkStore = deepLinkStore
        Task { @MainActor in
            await syncFCMTokenIfPossible(trigger: "configure")
        }
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // `UMCAppApp.init()`과의 호출 순서가 보장되지 않으므로 Messaging에 접근하기 전에 한 번 더
        // 호출한다. `FirebaseApp.app()` 가드 덕에 멱등이다.
        UMCAppApp.configureFirebaseIfNeeded()
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        registerRemoteNotificationsIfAuthorized()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(memberProfileDidUpdate),
            name: .memberProfileUpdated,
            object: nil
        )
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        Task { @MainActor in
            await syncFCMTokenIfPossible(trigger: "didBecomeActive")
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        logger.error("[Push] APNs 등록 실패: \(error.localizedDescription, privacy: .public)")
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        saveNoticeHistory(from: notification.request.content)
        handlePush(userInfo: notification.request.content.userInfo, isTap: false)
        completionHandler([.banner, .sound, .badge])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        saveNoticeHistory(from: response.notification.request.content)
        handlePush(userInfo: response.notification.request.content.userInfo, isTap: true)
        completionHandler()
    }

    /// 백그라운드로 도착한 데이터 푸시.
    ///
    /// 서버가 `content-available: 1`(APNs `ApnsConfig`)을 실어 줄 때만 호출된다 — 지금 서버는
    /// 이 플래그를 붙이지 않아 실질적으로는 잠자는 경로다. 그래도 `UIBackgroundModes` 에
    /// `remote-notification` 을 선언해 둔 이상 대응 핸들러는 있어야, 플래그가 켜지는 날
    /// 앱이 화면 밖에서도 출석 상태를 따라잡는다.
    ///
    /// - Note: 여기서는 ``saveNoticeHistory(from:)`` 를 부르지 않는다. 알림을 동반한 포그라운드
    ///   푸시는 이 콜백과 `willPresent` 가 함께 불려, 저장하면 같은 항목이 알림 보관함에 두 번
    ///   쌓인다.
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        handlePush(userInfo: userInfo, isTap: false)
        return .newData
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    /// FCM 토큰이 갱신되면 UserDefaults에 저장하고 서버 동기화를 시도한다.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }

        let storedToken = UserDefaults.standard.string(forKey: AppStorageKey.userFCMToken) ?? ""
        guard storedToken != fcmToken else { return }

        UserDefaults.standard.set(fcmToken, forKey: AppStorageKey.userFCMToken)
        NotificationCenter.default.post(name: .fcmTokenReceived, object: fcmToken)
        Task { @MainActor in
            await syncFCMTokenIfPossible(trigger: "messagingDelegate")
        }
    }
}

// MARK: - Notification.Name

extension Notification.Name {

    /// FCM 토큰 수신/갱신 알림
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
}

// MARK: - Private Function

private extension AppDelegate {

    /// 수신한 푸시를 타입별로 분기한다.
    ///
    /// 출석 상태 변경 푸시는 화면이 떠 있든 아니든 상태를 맞춰야 하므로 앱 내부 알림으로
    /// 흘려보내고(구독자는 `ActivityViewModel`), 화면 이동은 사용자가 알림을 탭했을 때만 한다.
    ///
    /// - Parameter isTap: 알림 탭으로 들어온 경로인지 (딥링크 이동은 탭일 때만)
    func handlePush(userInfo: [AnyHashable: Any], isTap: Bool) {
        let payload = PushPayload(userInfo: userInfo)

        if let scheduleId = payload.attendanceScheduleId {
            NotificationCenter.default.post(
                name: .attendanceStatusChanged,
                object: nil,
                userInfo: [Notification.attendanceScheduleIdKey: scheduleId]
            )
        }

        guard isTap, let deepLink = payload.deepLink else { return }
        deepLinkStore?.receive(deepLink)
    }

    /// 로그인/가입 직후 프로필이 저장되면 FCM 토큰을 다시 동기화한다.
    ///
    /// 앱 실행 시점에는 `memberId`가 없어 ``syncFCMTokenIfPossible(trigger:)``가 조기 반환하고,
    /// 같은 세션 안에서 로그인해도 `applicationDidBecomeActive`는 다시 호출되지 않는다.
    @objc
    func memberProfileDidUpdate() {
        Task { @MainActor in
            await syncFCMTokenIfPossible(trigger: "memberProfileUpdated")
        }
    }

    /// FCM 토큰을 서버에 동기화한다.
    ///
    /// 멤버 ID와 토큰이 모두 확보됐고, 직전에 올린 (멤버, 토큰) 조합과 다를 때만 등록한다.
    /// - Parameter trigger: 동기화를 트리거한 이벤트 이름 (로그용)
    @MainActor
    func syncFCMTokenIfPossible(trigger: String) async {
        guard let container else { return }

        let memberId = AppStorageKey.legacyMemberIdInt()
        let fcmToken = UserDefaults.standard.string(forKey: AppStorageKey.userFCMToken) ?? ""
        guard memberId != 0, !fcmToken.isEmpty else { return }

        if let lastFailed = lastFailedFCMUpload,
           lastFailed.memberId == memberId,
           lastFailed.token == fcmToken {
            return
        }

        let uploadedToken = UserDefaults.standard.string(forKey: AppStorageKey.uploadedFCMToken) ?? ""
        let uploadedMemberId = UserDefaults.standard.integer(forKey: AppStorageKey.uploadedFCMMemberId)
        guard uploadedToken != fcmToken || uploadedMemberId != memberId else { return }

        do {
            try await container
                .resolve(RegisterFCMTokenUseCaseProtocol.self)
                .execute(fcmToken: fcmToken)
            lastFailedFCMUpload = nil
            UserDefaults.standard.set(fcmToken, forKey: AppStorageKey.uploadedFCMToken)
            UserDefaults.standard.set(memberId, forKey: AppStorageKey.uploadedFCMMemberId)
        } catch {
            lastFailedFCMUpload = (memberId: memberId, token: fcmToken)
            logger.error(
                """
                [FCM] 토큰 등록 실패 trigger=\(trigger, privacy: .public) \
                error=\(error.localizedDescription, privacy: .public)
                """
            )
        }
    }

    /// 수신한 푸시 콘텐츠를 알림 보관함(SwiftData)에 저장한다.
    ///
    /// - Parameter content: 푸시 알림 콘텐츠. `title`/`body`가 비어 있으면 `userInfo`에서 찾는다.
    func saveNoticeHistory(from content: UNNotificationContent) {
        guard let modelContext else { return }

        let userInfo = content.userInfo
        let title = content.title.isEmpty
            ? (userInfo["title"] as? String ?? Constants.fallbackTitle)
            : content.title
        let body = content.body.isEmpty
            ? (userInfo["body"] as? String ?? userInfo["message"] as? String ?? "")
            : content.body
        let icon = container?
            .resolve(ClassifyNoticeUseCaseProtocol.self)
            .execute(title: title, content: body) ?? .info

        modelContext.insert(
            NoticeHistoryData(title: title, content: body, icon: icon, createdAt: .now)
        )
        try? modelContext.save()
    }

    /// 푸시 알림 권한 상태를 확인하고, 허용 시 원격 알림을 등록한다.
    ///
    /// 권한이 미결정이면 권한 요청 프롬프트를 먼저 띄운다.
    func registerRemoteNotificationsIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.requestRemoteNotificationRegistration()
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(
                    options: Constants.authorizationOptions
                ) { granted, _ in
                    guard granted else { return }
                    self.requestRemoteNotificationRegistration()
                }
            default:
                self.logger.notice("[Push] 알림 권한이 없어 원격 알림을 등록하지 않습니다.")
            }
        }
    }

    func requestRemoteNotificationRegistration() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
}
