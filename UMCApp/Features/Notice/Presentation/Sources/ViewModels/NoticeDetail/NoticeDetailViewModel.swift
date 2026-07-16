//
//  NoticeDetailViewModel.swift
//  NoticePresentation
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import SwiftData
import CoreDomain
import UMCFoundation
import CoreDI
import NoticeDomain

/// 공지사항 상세 화면 ViewModel
///
/// 공지 조회/수정/삭제, 투표 처리, 열람 현황(The Ping) 관리를 담당합니다.
@Observable
public final class NoticeDetailViewModel {

    // MARK: - Dependency

    /// DI Container
    public let container: DIContainer

    /// UseCase
    public var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    public var authorizationUseCase: AuthorizationUseCaseProtocol {
        container.resolve(AuthorizationUseCaseProtocol.self)
    }

    public var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    public var noticeReadRepository: NoticeReadRepositoryProtocol {
        container.resolve(NoticeReadRepositoryProtocol.self)
    }

    public var userSessionManager: UserSessionManager {
        container.resolve(UserSessionManager.self)
    }

    public var currentMemberId: Int {
        AppStorageKey.legacyMemberIdInt()
    }

    // MARK: - Core State

    /// 공지 상세 상태
    public var noticeState: Loadable<NoticeDetail>

    /// 작성자 표시 텍스트 (닉네임/이름-기수TH UMC 직책)
    public var authorDisplayName: String = ""
    /// 작성자 상세 프로필 요약 정보
    public var authorProfileSummary: MemberProfileSummary?
    /// 작성자 프로필 추가 조회 진행 상태
    public var isAuthorProfileLoading: Bool = false
    /// 작성자 프로필 추가 조회 완료 여부
    public var hasResolvedAuthorProfile: Bool = false

    /// 액션 메뉴 표시 여부
    public var showingActionMenu: Bool = false

    /// Alert 프롬프트
    public var alertPrompt: AlertPrompt?

    /// 투표 응답 전송 진행 상태
    public var isSubmittingVote: Bool = false

    /// 공지 상세 초기 fetch 완료 전까지 투표 영역 로딩 표시 여부
    public var isVoteLoading: Bool = true

    /// 공지 ID
    public let noticeID: String

    /// 읽음 처리 완료 여부(중복 호출 방지)
    public var hasMarkedAsRead: Bool = false

    /// Error Handler
    public var errorHandler: ErrorHandler

    /// Navigation 콜백
    public var onEditNotice: ((Int) -> Void)?
    public var onDeleteSuccess: (() -> Void)?

    // MARK: - Read Status State

    /// 공지 열람 현황 Sheet 표시 여부
    public var showReadStatusSheet: Bool = false

    /// 공지 열람 현황 데이터 상태
    public var readStatusState: Loadable<NoticeReadStatus> = .idle

    /// 공지 열람 통계 API 원본 값
    public var readStatics: NoticeReadStatics?

    /// 공지 열람 통계(read-statics) 로딩 상태
    public var isReadStaticsLoading: Bool = false

    /// 공지 열람 통계 선조회 여부
    public var hasPrefetchedReadStatics: Bool = false

    /// 읽음 사용자 페이지 커서
    public var readNextCursor: Int?

    /// 안읽음 사용자 페이지 커서
    public var unreadNextCursor: Int?

    /// 읽음 사용자 다음 페이지 존재 여부
    public var hasNextReadPage: Bool = false

    /// 안읽음 사용자 다음 페이지 존재 여부
    public var hasNextUnreadPage: Bool = false

    /// 페이지네이션 진행 상태
    public var isLoadingMoreReadStatus: Bool = false

    /// 열람 현황 재시도 진행 상태 (실패 화면의 버튼 내부 로딩 표시용)
    public var isRetryingReadStatus: Bool = false

    /// 선택된 탭 (확인/미확인)
    public var selectedReadTab: ReadStatusTab = .confirmed

    /// 선택된 필터 타입
    public var selectedFilter: ReadStatusFilterType = .all
    
    // MARK: - AI Reading Summary State

    /// AI 읽기 요약 시트 표시 여부
    var showReadingSummarySheet: Bool = false

    /// AI 읽기 요약 진행 단계
    var readingSummaryPhase: ReadingSummaryPhase = .idle

    /// AI 읽기 요약 스트리밍 중 현재까지 생성된 텍스트
    var readingSummaryStreamingText: String = ""

    /// AI 읽기 요약용 ModelContext (View에서 주입)
    var readingSummaryModelContext: ModelContext?

    // MARK: - Permission State

    /// 공지 수정 가능 여부 (WRITE/MANAGE)
    public var canEditNotice: Bool = false

    /// 공지 삭제 가능 여부 (DELETE/MANAGE)
    public var canDeleteNotice: Bool = false

    /// 수정 화면 진입에 필요한 상세 데이터 준비 완료 여부
    public var isDetailPreparedForEdit: Bool = false

    /// 수신 확인 현황 접근 가능 여부
    public var canViewReadStatus: Bool {
        guard let detail = noticeState.value else { return false }
        return NoticeReadStatusPermissionEvaluator.canViewReadStatus(
            roles: resolvedMemberRoles,
            userChapterId: resolvedChapterId,
            userSchoolId: resolvedSchoolId,
            targetAudience: detail.targetAudience
        )
    }

    // MARK: - Read Status Computed

    /// 현재 선택된 탭에 따른 필터링된 사용자 목록
    public var filteredReadStatusUsers: [ReadStatusUser] {
        guard let readStatus = readStatusState.value else { return [] }
        return selectedReadTab == .confirmed ? readStatus.confirmedUsers : readStatus.unconfirmedUsers
    }

    /// 하단 메시지 표시 여부 (확인 탭에서만)
    public var shouldShowBottomMessage: Bool {
        selectedReadTab == .confirmed && readStatusState.value != nil
    }

    /// 하단 메시지 텍스트
    public var bottomMessage: String {
        readStatusState.value?.bottomMessage ?? ""
    }

    /// 확인한 인원 수 (버튼용)
    public var confirmedCount: String {
        if let readStatics { return readStatics.readCount }
        return readStatusState.value?.confirmedCount ?? "0"
    }

    /// 확인하지 않은 인원 수 (버튼용)
    public var unconfirmedCount: String {
        if let readStatics { return readStatics.unreadCount }
        return readStatusState.value?.unconfirmedCount ?? "0"
    }

    /// 전체 인원 수 (버튼용)
    public var totalCount: Int {
        if let readStatics { return Int(readStatics.totalCount) ?? 0 }
        let confirmed = Int(confirmedCount) ?? 0
        let unconfirmed = Int(unconfirmedCount) ?? 0
        return confirmed + unconfirmed
    }

    /// 읽음 비율(0.0 ~ 1.0)
    public var readRate: Double {
        if let readStatics {
            return Self.normalizedReadRate(from: readStatics.readRate)
        }
        guard totalCount > 0 else { return 0 }
        return Double(Int(confirmedCount) ?? 0) / Double(totalCount)
    }

    /// 지부별로 그룹화된 사용자
    public var groupedUsersByBranch: [String: [ReadStatusUser]] {
        Dictionary(grouping: filteredReadStatusUsers, by: { $0.branch })
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    /// 학교별로 그룹화된 사용자
    public var groupedUsersBySchool: [String: [ReadStatusUser]] {
        Dictionary(grouping: filteredReadStatusUsers, by: { $0.campus })
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    // MARK: - Initialization

    public init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        model: NoticeDetail
    ) {
        self.container = container
        self.noticeID = model.id
        self.errorHandler = errorHandler
        self.noticeState = .loaded(model)
        let normalizedModel = normalizeTargetGenerationIfNeeded(in: model)
        noticeState = .loaded(normalizedModel)
        authorDisplayName = normalizedModel.defaultAuthorDisplayName
    }

    // MARK: - Function

    /// ErrorHandler 업데이트
    public func updateErrorHandler(_ handler: ErrorHandler) {
        errorHandler = handler
    }

    /// 액션 메뉴 표시
    public func showActionMenu() {
        showingActionMenu = true
    }

    // MARK: - Author Profile

    /// 공지 작성자 표기명을 목록/상세 응답에 포함된 닉네임/이름 값으로 갱신합니다.
    @MainActor
    public func refreshAuthorDisplayName(for detail: NoticeDetail) {
        authorDisplayName = detail.defaultAuthorDisplayName
    }

    /// 화면에 즉시 노출할 작성자명을 반환합니다.
    public func displayedAuthorName(for detail: NoticeDetail) -> String {
        authorDisplayName.isEmpty ? detail.defaultAuthorDisplayName : authorDisplayName
    }

    /// 화면에 노출할 작성자 이름/닉네임 텍스트를 반환합니다.
    public func displayedAuthorIdentity(for detail: NoticeDetail) -> String {
        if let authorProfileSummary {
            let name = authorProfileSummary.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let nickname = authorProfileSummary.nickname.trimmingCharacters(in: .whitespacesAndNewlines)

            if !name.isEmpty && !nickname.isEmpty {
                return "\(nickname)/\(name)"
            }
            return !nickname.isEmpty ? nickname : name
        }

        let fallbackName = detail.authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallbackNickname = detail.authorNickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !fallbackName.isEmpty && !fallbackNickname.isEmpty {
            return "\(fallbackNickname)/\(fallbackName)"
        }
        return displayedAuthorName(for: detail)
    }

    /// 화면에 노출할 작성자 프로필 한 줄 텍스트를 반환합니다.
    public func displayedAuthorProfileLine(for detail: NoticeDetail) -> String {
        let identity = displayedAuthorIdentity(for: detail)
        let generation: String
        let roleName: String

        if let authorProfileSummary {
            generation = String(authorProfileSummary.generation)
            roleName = authorProfileSummary.roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            generation = detail.generation
            roleName = ""
        }

        var components: [String] = []
        if let genInt = Int(generation), genInt > 0 {
            components.append("\(generation)\(ordinalSuffix(for: genInt))")
        }
        if !roleName.isEmpty && roleName != ManagementTeam.challenger.korean {
            components.append(roleName)
        }
        components.append(identity)

        return components.joined(separator: " ")
    }

    /// 화면에 노출할 작성자 프로필 이미지 URL을 반환합니다.
    public func displayedAuthorImageURL(for detail: NoticeDetail) -> String? {
        authorProfileSummary?.profileImageURL ?? detail.authorImageURL
    }

    private func ordinalSuffix(for generation: Int) -> String {
        let suffixBase = generation % 100
        if (11...13).contains(suffixBase) {
            return "th"
        }

        switch generation % 10 {
        case 1:
            return "st"
        case 2:
            return "nd"
        case 3:
            return "rd"
        default:
            return "th"
        }
    }

    // MARK: - Generation Helper

    /// targetAudience.generation 값이 gisu PK인 경우 로컬 매핑으로 실제 기수(gen)로 보정합니다.
    ///
    /// 서버가 `targetGisu`를 내려주면 DTO 매퍼에서 우선 적용되고,
    /// 해당 값이 없거나 `targetGisuId`만 존재할 때만 이 보정 로직이 동작합니다.
    public func normalizeTargetGenerationIfNeeded(in detail: NoticeDetail) -> NoticeDetail {
        let originalGeneration = detail.targetAudience.generation
        let resolvedGeneration = resolveGeneration(from: originalGeneration)

        guard resolvedGeneration != originalGeneration else {
            return detail
        }

        let normalizedAudience = TargetAudience(
            generation: resolvedGeneration,
            scope: detail.targetAudience.scope,
            parts: detail.targetAudience.parts,
            chapterId: detail.targetAudience.chapterId,
            schoolId: detail.targetAudience.schoolId,
            branches: detail.targetAudience.branches,
            schools: detail.targetAudience.schools
        )

        return NoticeDetail(
            id: detail.id,
            generation: resolvedGeneration,
            scope: detail.scope,
            category: detail.category,
            isMustRead: detail.isMustRead,
            title: detail.title,
            content: detail.content,
            authorID: detail.authorID,
            authorMemberId: detail.authorMemberId,
            authorNickname: detail.authorNickname,
            authorName: detail.authorName,
            authorImageURL: detail.authorImageURL,
            createdAt: detail.createdAt,
            updatedAt: detail.updatedAt,
            targetAudience: normalizedAudience,
            hasPermission: detail.hasPermission,
            images: detail.images,
            imageItems: detail.imageItems,
            links: detail.links,
            vote: detail.vote
        )
    }

    /// 현재 값이 gisuId인지 판별하여 실제 기수(gen)를 반환합니다.
    private func resolveGeneration(from value: String) -> String {
        guard !value.isEmpty else { return value }
        do {
            let pairs = try genRepository.fetchGenGisuIdPairs()
            if let matchedGen = pairs.first(where: { $0.gisuId == value })?.gen {
                return matchedGen
            }
            return value
        } catch {
            return value
        }
    }

    private var resolvedMemberRoles: [ManagementTeam] {
        let storedRoles = (UserDefaults.standard.array(forKey: AppStorageKey.memberRoles) as? [String] ?? [])
            .compactMap(ManagementTeam.init(rawValue:))
        let storedHighestRole = UserDefaults.standard.string(forKey: AppStorageKey.memberRole)
            .flatMap(ManagementTeam.init(rawValue:))
        let combinedRoles = storedRoles + [userSessionManager.currentRole] + [storedHighestRole].compactMap { $0 }

        return Array(Set(combinedRoles))
    }

    private var resolvedChapterId: String? {
        let str = UserDefaults.standard.string(forKey: AppStorageKey.chapterId) ?? ""
        return str.isEmpty || str == "0" ? nil : str
    }

    private var resolvedSchoolId: String? {
        let str = UserDefaults.standard.string(forKey: AppStorageKey.schoolId) ?? ""
        return str.isEmpty || str == "0" ? nil : str
    }

}

private extension NoticeDetailViewModel {
    static func normalizedReadRate(from rawValue: String) -> Double {
        let parsedRate = Double(rawValue) ?? 0

        if parsedRate > 1 {
            return min(max(parsedRate / 100, 0), 1)
        }

        return min(max(parsedRate, 0), 1)
    }
}
