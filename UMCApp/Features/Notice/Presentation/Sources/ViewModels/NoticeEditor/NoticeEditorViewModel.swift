//
//  NoticeEditorViewModel.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/1/26.
//

import Foundation
import SwiftUI
import PhotosUI
import SwiftData
import UIKit
import UMCFoundation
import CoreDI
import CoreDomain
import NoticeDomain

/// 공지사항 에디터 ViewModel
///
/// 공지 생성/수정, 카테고리/타겟 선택, 이미지/링크/투표 첨부 상태를 관리합니다.
@Observable
public final class NoticeEditorViewModel {

    // MARK: - Dependency

    public let container: DIContainer
    public var modelContext: ModelContext?

    public var noticeUseCase: NoticeUseCaseProtocol {
        container.resolve(NoticeUseCaseProtocol.self)
    }

    public var targetUseCase: NoticeEditorTargetUseCaseProtocol {
        container.resolve(NoticeEditorTargetUseCaseProtocol.self)
    }

    public var genRepository: ChallengerGenRepositoryProtocol {
        container.resolve(ChallengerGenRepositoryProtocol.self)
    }

    public var errorHandler: ErrorHandler?

    // MARK: - Mode

    /// 편집 모드 (생성 or 수정)
    public let mode: NoticeEditorMode

    // MARK: - User Context

    public var memberId: Int {
        AppStorageKey.legacyMemberIdInt()
    }

    public var gisuId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.gisuId)
    }

    public var organizationId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.organizationId)
    }

    public var schoolId: Int {
        UserDefaults.standard.integer(forKey: AppStorageKey.schoolId)
    }

    /// 사용자 조직 타입 (AppStorage 반영)
    public var organizationType: OrganizationType?

    /// 사용자 권한/역할 (AppStorage 반영)
    public var memberRole: ManagementTeam?

    /// 뷰에서 전달받는 사용자 컨텍스트(우선 적용)
    public var userGisuId: String?
    public var userChapterId: String?
    public var selectedGenerationValue: String?

    public var resolvedGisuId: String {
        userGisuId ?? String(gisuId)
    }

    /// `resolvedGisuId`의 정수 표현. 파싱 실패·음수는 모두 0(미해결)으로 수렴시킵니다.
    public var resolvedGisuIdValue: Int {
        max(Int(resolvedGisuId) ?? 0, 0)
    }

    public var resolvedChapterId: String {
        userChapterId ?? String(organizationId)
    }

    public var selectedGenerationTitle: String? {
        guard let selectedGenerationValue else { return nil }
        return "\(selectedGenerationValue)기"
    }

    // MARK: - View State

    /// 공지 생성/수정 상태
    ///
    /// ViewModel 기능을 extension 파일로 분리해 관리하므로,
    /// 동일 타입 extension에서도 상태 전환이 가능하도록 setter를 내부 공개합니다.
    public var createState: Loadable<NoticeDetail> = .idle

    /// 선택된 메인 카테고리
    public var selectedCategory: EditorMainCategory {
        didSet {
            if oldValue != selectedCategory {
                subCategorySelection = EditorSubCategorySelection()
            }
        }
    }

    /// 서브카테고리 선택 상태
    public var subCategorySelection = EditorSubCategorySelection()

    /// 공지 타겟(지부, 학교, 파트) 시트 표시 여부
    public var activeSheetType: TargetSheetType?

    /// 사용자 조직 타입에 따라 노출 가능한 메인 카테고리 목록
    public var availableCategories: [EditorMainCategory]

    /// 지부 선택 시트 목록 (중앙 선택 시)
    public var branchOptions: [NoticeTargetOption] = []

    /// 학교 선택 시트 목록
    public var schoolOptions: [NoticeTargetOption] = []

    /// 타겟(지부/학교/파트) 시트 데이터 로딩 상태
    public var targetOptionsState: Loadable<Bool> = .idle

    /// 공지사항 제목
    public var title: String = ""

    /// 공지사항 본문 (일반 텍스트 — 서버 전송용)
    public var content: String = ""

    /// 리치 텍스트 에디터 툴바 ViewModel
    public var editorToolbarViewModel: EditorToolbarViewModel = EditorToolbarViewModel()

    /// 리치 텍스트 에디터 본문 (NSAttributedString — 로컬 편집용)
    public var richAttributedContent: NSAttributedString = NSAttributedString(string: "")

    /// 투표 폼 시트 표시 여부
    public var showVoting: Bool = false

    /// 투표 폼 데이터
    public var voteFormData: VoteFormData = VoteFormData()

    /// 투표 확정 여부
    public var isVoteConfirmed: Bool = false

    /// 화면 AlertPrompt
    public var alertPrompt: AlertPrompt?

    /// PhotosPicker 선택 아이템
    public var selectedPhotoItems: [PhotosPickerItem] = []

    /// 로드된 UIImage 목록
    public var selectedImages: [UIImage] = []

    /// 첨부 이미지 카드 목록
    public var noticeImages: [NoticeImageItem] = []

    /// 첨부 링크 카드 목록
    public var noticeLinks: [NoticeLinkItem] = []

    /// 알림 발송 여부
    public var allowAlert: Bool = true

    // MARK: - AI State

    /// AI 개선 시작 전 확인 다이얼로그 표시 여부
    public var showAIConfirmation: Bool = false

    /// AI 글 개선 처리 중 여부
    public var isAIProcessing: Bool = false

    /// AI 스트리밍 진행 중 현재까지 생성된 텍스트 (진행 상황 표시용)
    public var aiStreamingText: String = ""

    /// AI 토큰 사용량 (iOS 26.4+ 에서만 채워짐)
    public var aiTokenUsage: AITokenUsage?

    /// 에디터가 열려 있는 동안 성공적으로 확정된 AI 토큰 누적 사용량
    public var aiCumulativeUsedTokens: Int = 0

    /// AI 개선 완료 후 확인 버튼 대기 중 상태 (오버레이 유지용)
    public var showAICompletionSummary: Bool = false
    
    // MARK: - AI Summary State

    /// 외부 텍스트 붙여넣기 + AI 요약 시트 표시 여부
    var showAISummaryInput: Bool = false

    /// 붙여넣기 시트의 입력 텍스트 버퍼 (시트 닫힐 때 초기화)
    var summarySourceText: String = ""

    /// AI 요약 요청 전 확인 다이얼로그 표시 여부
    var showAISummaryConfirmation: Bool = false

    /// AI 요약 처리 중 여부
    var isAISummaryProcessing: Bool = false

    /// AI 요약 스트리밍 진행 중 현재까지 생성된 텍스트 (진행 상황 표시용)
    var aiSummaryStreamingText: String = ""

    /// AI 요약 완료 후 초안 검토 대기 중 상태
    var showAISummaryDraftReview: Bool = false

    /// AI 요약으로 생성된 제목 + 본문 초안 (검토 후 수락 or 기각)
    var pendingSummaryDraft: AISummaryDraft?

    // MARK: - Edit Snapshot

    /// 수정 화면 원본 제목
    public var originalTitle: String = ""

    /// 수정 화면 원본 본문
    public var originalContent: String = ""

    /// 수정 화면 원본 링크 목록
    public var originalLinks: [String] = []

    /// 수정 화면 원본 이미지 ID 목록 (순서 유지)
    public var originalImageIds: [String] = []
    /// 수정 화면 원본 이미지 URL 목록 (ID 미포함 응답 대비)
    public var originalImageURLs: [String] = []

    /// 수정 화면 원본 투표 폼
    public var originalVoteFormData: VoteFormData?

    /// 수정 진입 시점의 원본 투표 스냅샷
    public var initialVoteSnapshot: VoteSnapshot?

    // MARK: - Derived State

    /// 수정 모드 여부
    public var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }

    /// 저장 가능 여부
    ///
    /// 생성: 제목/내용 필수 (+ 운영진 공지는 기수 필수)
    /// 수정: 제목/내용 필수 + 실제 변경사항 존재
    public var canSubmit: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasRequiredFields = !trimmedTitle.isEmpty && !trimmedContent.isEmpty

        switch mode {
        case .create:
            // 서버 스펙: 운영진 공지는 기수 필수
            if case .management = selectedCategory, resolvedGisuIdValue <= 0 {
                return false
            }
            return hasRequiredFields
        case .edit:
            return hasRequiredFields && hasEditableChanges
        }
    }

    // MARK: - Initializer

    public init(
        container: DIContainer,
        mode: NoticeEditorMode = .create,
        selectedGisuId: String? = nil,
        initialCategory: EditorMainCategory? = nil,
        memberRoleRaw: String? = nil
    ) {
        self.container = container
        self.mode = mode
        self.userGisuId = selectedGisuId.map { String($0) }

        let role = memberRoleRaw.flatMap { ManagementTeam(rawValue: $0) }
        let categories = Self.availableCategories(for: nil, memberRole: role)
        availableCategories = categories
        selectedCategory = initialCategory.flatMap { categories.contains($0) ? $0 : nil } ?? categories.first ?? .all

        if case .edit(_, let notice) = mode {
            loadNoticeForEdit(notice)
        }

        refreshSelectedGenerationValue()
    }

    // MARK: - Helper

    /// 선택된 gisuId를 사용자 표시용 기수 값으로 역매핑합니다.
    public func refreshSelectedGenerationValue() {
        let currentGisuId = resolvedGisuId
        guard let idInt = Int(currentGisuId), idInt > 0 else {
            selectedGenerationValue = nil
            return
        }

        do {
            let selectedGeneration = try genRepository
                .fetchGenGisuIdPairs()
                .first(where: { $0.gisuId == String(currentGisuId) })?
                .gen
            selectedGenerationValue = selectedGeneration ?? currentGisuId
        } catch {
            selectedGenerationValue = currentGisuId
        }
    }
    
    /// 선택된 PhotosPickerItem 목록으로부터 UIImage를 비동기로 로드합니다.
    ///
    /// 일부 항목 로드에 실패해도 성공한 이미지는 selectedImages에 저장됩니다.
    public func loadSelectedImages() async {
        guard !selectedPhotoItems.isEmpty else {
            selectedImages = []
            return
        }
        var loadedImages: [UIImage] = []
        for item in selectedPhotoItems {
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    loadedImages.append(uiImage)
                } else {
                    print("[NoticeEditorViewModel] 이미지 데이터 변환 실패 (항목 건너뜀)")
                }
            } catch {
                print("[NoticeEditorViewModel] 이미지 로드 실패: \(error.localizedDescription) (항목 건너뜀)")
            }
        }
        selectedImages = loadedImages
        await didLoadImages(images: loadedImages)
    }
}
