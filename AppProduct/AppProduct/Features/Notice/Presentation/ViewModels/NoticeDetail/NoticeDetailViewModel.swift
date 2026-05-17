//
//  NoticeDetailViewModel.swift
//  AppProduct
//
//  Created by 이예지 on 2/2/26.
//

import SwiftUI

/// 공지사항 상세 화면 ViewModel
///
/// 공지 조회/수정/삭제, 투표 처리, 열람 현황(The Ping) 관리를 담당합니다.
@Observable
final class NoticeDetailViewModel {

    // MARK: - Dependency

    /// DI Container
    let container: DIContainer

    /// UseCase
    var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    var authorizationUseCase: AuthorizationUseCaseProtocol {
        container.resolve(AuthorizationUseCaseProtocol.self)
    }

    var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    var noticeReadRepository: NoticeReadRepositoryProtocol {
        container.resolve(NoticeReadRepositoryProtocol.self)
    }

    var userSessionManager: UserSessionManager {
        container.resolve(UserSessionManager.self)
    }

    var currentMemberId: Int {
        AppStorageKey.legacyMemberIdInt()
    }

    // MARK: - Core State

    /// 공지 상세 상태
    var noticeState: Loadable<NoticeDetail>

    /// 작성자 표시 텍스트 (닉네임/이름-기수TH UMC 직책)
    var authorDisplayName: String = ""
    /// 작성자 상세 프로필 요약 정보
    var authorProfileSummary: MemberProfileSummary?
    /// 작성자 프로필 추가 조회 진행 상태
    var isAuthorProfileLoading: Bool = false
    /// 작성자 프로필 추가 조회 완료 여부
    var hasResolvedAuthorProfile: Bool = false

    /// 액션 메뉴 표시 여부
    var showingActionMenu: Bool = false

    /// Alert 프롬프트
    var alertPrompt: AlertPrompt?

    /// 투표 응답 전송 진행 상태
    var isSubmittingVote: Bool = false

    /// 공지 상세 초기 fetch 완료 전까지 투표 영역 로딩 표시 여부
    var isVoteLoading: Bool = true

    /// 공지 ID
    let noticeID: Int

    /// 읽음 처리 완료 여부(중복 호출 방지)
    var hasMarkedAsRead: Bool = false

    /// Error Handler
    var errorHandler: ErrorHandler

    /// Navigation 콜백
    var onEditNotice: ((Int) -> Void)?
    var onDeleteSuccess: (() -> Void)?

    // MARK: - Read Status State

    /// 공지 열람 현황 Sheet 표시 여부
    var showReadStatusSheet: Bool = false

    /// 공지 열람 현황 데이터 상태
    var readStatusState: Loadable<NoticeReadStatus> = .idle

    /// 공지 열람 통계 API 원본 값
    var readStatics: NoticeReadStaticsDTO?

    /// 공지 열람 통계(read-statics) 로딩 상태
    var isReadStaticsLoading: Bool = false

    /// 공지 열람 통계 선조회 여부
    var hasPrefetchedReadStatics: Bool = false

    /// 읽음 사용자 페이지 커서
    var readNextCursor: Int?

    /// 안읽음 사용자 페이지 커서
    var unreadNextCursor: Int?

    /// 읽음 사용자 다음 페이지 존재 여부
    var hasNextReadPage: Bool = false

    /// 안읽음 사용자 다음 페이지 존재 여부
    var hasNextUnreadPage: Bool = false

    /// 페이지네이션 진행 상태
    var isLoadingMoreReadStatus: Bool = false

    /// 열람 현황 재시도 진행 상태 (실패 화면의 버튼 내부 로딩 표시용)
    var isRetryingReadStatus: Bool = false

    /// 선택된 탭 (확인/미확인)
    var selectedReadTab: ReadStatusTab = .confirmed

    /// 선택된 필터 타입
    var selectedFilter: ReadStatusFilterType = .all

    // MARK: - Permission State

    /// 공지 수정 가능 여부 (WRITE/MANAGE)
    var canEditNotice: Bool = false

    /// 공지 삭제 가능 여부 (DELETE/MANAGE)
    var canDeleteNotice: Bool = false

    /// 수정 화면 진입에 필요한 상세 데이터 준비 완료 여부
    var isDetailPreparedForEdit: Bool = false

    /// 수신 확인 현황 접근 가능 여부
    var canViewReadStatus: Bool {
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
    var filteredReadStatusUsers: [ReadStatusUser] {
        guard let readStatus = readStatusState.value else { return [] }
        return selectedReadTab == .confirmed ? readStatus.confirmedUsers : readStatus.unconfirmedUsers
    }

    /// 하단 메시지 표시 여부 (확인 탭에서만)
    var shouldShowBottomMessage: Bool {
        selectedReadTab == .confirmed && readStatusState.value != nil
    }

    /// 하단 메시지 텍스트
    var bottomMessage: String {
        readStatusState.value?.bottomMessage ?? ""
    }

    /// 확인한 인원 수 (버튼용)
    var confirmedCount: Int {
        if let readStatics {
            return Int(readStatics.readCount) ?? 0
        }
        return readStatusState.value?.confirmedCount ?? 0
    }

    /// 확인하지 않은 인원 수 (버튼용)
    var unconfirmedCount: Int {
        if let readStatics {
            return Int(readStatics.unreadCount) ?? 0
        }
        return readStatusState.value?.unconfirmedCount ?? 0
    }

    /// 전체 인원 수 (버튼용)
    var totalCount: Int {
        if let readStatics {
            return Int(readStatics.totalCount) ?? 0
        }
        return readStatusState.value?.totalCount ?? 0
    }

    /// 읽음 비율(0.0 ~ 1.0)
    var readRate: Double {
        if let readStatics {
            return Self.normalizedReadRate(from: readStatics.readRate)
        }

        guard totalCount > 0 else { return 0 }
        return Double(confirmedCount) / Double(totalCount)
    }

    /// 지부별로 그룹화된 사용자
    var groupedUsersByBranch: [String: [ReadStatusUser]] {
        Dictionary(grouping: filteredReadStatusUsers, by: { $0.branch })
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    /// 학교별로 그룹화된 사용자
    var groupedUsersBySchool: [String: [ReadStatusUser]] {
        Dictionary(grouping: filteredReadStatusUsers, by: { $0.campus })
            .sorted { $0.key < $1.key }
            .reduce(into: [:]) { $0[$1.key] = $1.value }
    }

    // MARK: - Initialization

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        model: NoticeDetail
    ) {
        self.container = container
        self.noticeID = Int(model.id) ?? 0
        self.errorHandler = errorHandler
        self.noticeState = .loaded(model)
        let normalizedModel = normalizeTargetGenerationIfNeeded(in: model)
        noticeState = .loaded(normalizedModel)
        authorDisplayName = normalizedModel.defaultAuthorDisplayName
    }

    // MARK: - Function

    /// ErrorHandler 업데이트
    func updateErrorHandler(_ handler: ErrorHandler) {
        errorHandler = handler
    }

    /// 액션 메뉴 표시
    func showActionMenu() {
        showingActionMenu = true
    }

    // MARK: - Author Profile

    /// 공지 작성자 표기명을 목록/상세 응답에 포함된 닉네임/이름 값으로 갱신합니다.
    @MainActor
    func refreshAuthorDisplayName(for detail: NoticeDetail) {
        authorDisplayName = detail.defaultAuthorDisplayName
    }

    /// 화면에 즉시 노출할 작성자명을 반환합니다.
    func displayedAuthorName(for detail: NoticeDetail) -> String {
        authorDisplayName.isEmpty ? detail.defaultAuthorDisplayName : authorDisplayName
    }

    /// 화면에 노출할 작성자 이름/닉네임 텍스트를 반환합니다.
    func displayedAuthorIdentity(for detail: NoticeDetail) -> String {
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
    func displayedAuthorProfileLine(for detail: NoticeDetail) -> String {
        let identity = displayedAuthorIdentity(for: detail)
        let generation: Int
        let roleName: String

        if let authorProfileSummary {
            generation = authorProfileSummary.generation
            roleName = authorProfileSummary.roleName.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            generation = detail.generation
            roleName = ""
        }

        var components: [String] = []
        if generation > 0 {
            components.append("\(generation)\(ordinalSuffix(for: generation))")
        }
        if !roleName.isEmpty && roleName != ManagementTeam.challenger.korean {
            components.append(roleName)
        }
        components.append(identity)

        return components.joined(separator: " ")
    }

    /// 화면에 노출할 작성자 프로필 이미지 URL을 반환합니다.
    func displayedAuthorImageURL(for detail: NoticeDetail) -> String? {
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
    func normalizeTargetGenerationIfNeeded(in detail: NoticeDetail) -> NoticeDetail {
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
    private func resolveGeneration(from value: Int) -> Int {
        guard value > 0 else { return value }
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

    private var resolvedChapterId: Int? {
        let chapterId = UserDefaults.standard.integer(forKey: AppStorageKey.chapterId)
        return chapterId > 0 ? chapterId : nil
    }

    private var resolvedSchoolId: Int? {
        let schoolId = UserDefaults.standard.integer(forKey: AppStorageKey.schoolId)
        return schoolId > 0 ? schoolId : nil
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
