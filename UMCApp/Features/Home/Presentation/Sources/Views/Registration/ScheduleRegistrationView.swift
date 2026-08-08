//
//  ScheduleRegistrationView.swift
//  HomePresentation
//
//  Created by euijjang97 on 1/22/26.
//

import CoreDesignSystem
import CoreDI
import CoreLocation
import CoreUIComponents
import FoundationModels
import HomeDomain
import SwiftData
import SwiftUI
import UMCFoundation

/// 일정 등록/수정 화면.
///
/// 제목·장소·일시·태그·메모·출석 정책을 입력받아 생성 또는 수정을 수행한다. 생성 모드에서는
/// 온디바이스 AI 로 폼을 한 번에 채우는 시트를 제공한다.
///
/// `navigationDestination` 으로 실리므로 자체 `NavigationStack` 을 만들지 않는다.
public struct ScheduleRegistrationView: View {

    // MARK: - Property

    @State private var viewModel: ScheduleRegistrationViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ErrorHandler.self) private var errorHandler

    private let mode: Mode

    @State private var showAISheet: Bool = false

    /// 현재 펼쳐진 시작/종료 피커. `nil` 이면 모두 접힌 상태다.
    @State private var openScheduleSlot: ScheduleDateSlot?

    /// 화면의 동작 모드
    public enum Mode {
        case create
        case edit
    }

    // MARK: - Initializer

    /// - Parameters:
    ///   - container: UseCase 를 resolve 할 DI 컨테이너
    ///   - mode: 생성/수정 모드
    ///   - prefill: 수정 모드에서 폼에 채울 기존 일정
    ///   - prefillRoadAddress: 장소 프리필 시 우선 노출할 도로명 주소
    public init(
        container: DIContainer,
        mode: Mode = .create,
        prefill: ScheduleDetailData? = nil,
        prefillRoadAddress: String? = nil
    ) {
        self.mode = mode

        let viewModel = ScheduleRegistrationViewModel(container: container)
        if let prefill {
            viewModel.applyPrefill(from: prefill, roadAddress: prefillRoadAddress)
        }
        _viewModel = State(initialValue: viewModel)
    }

    // MARK: - Body

    public var body: some View {
        formContent
            .scrollDismissesKeyboard(.immediately)
            .navigation(naviTitle: navigationTitle, displayMode: .inline)
            .toolbar { toolbarContent }
            .alertPrompt(item: $viewModel.alertPrompt)
            .sheet(isPresented: $showAISheet) {
                AIAutofillSheet(viewModel: viewModel, isPresented: $showAISheet)
            }
            .task {
                viewModel.errorHandler = errorHandler
                viewModel.modelContext = modelContext
                viewModel.restoreDailyTokenUsage()
            }
    }

    // MARK: - Sections

    private var formContent: some View {
        Form {
            inlineErrorSection

            Section {
                titleField
            }

            placeSection

            Section {
                allDayToggle
                scheduleDateTimeSection
            }

            attendancePolicySection

            Section {
                TagSelectionRow(tagList: tagBinding)
            }

            Section {
                MemoEditor(memo: $viewModel.memo)
                    .equatable()
            }
        }
        .onChange(of: viewModel.startDate) { viewModel.startDateChanged() }
        .onChange(of: viewModel.endDate) { viewModel.endDateChanged() }
        .onChange(of: viewModel.isAllDay) { viewModel.prefillAttendancePolicyIfNeeded() }
        .onChange(of: viewModel.submitState) {
            if case .loaded = viewModel.submitState {
                dismiss()
            }
        }
    }

    /// 수정 모드 가드 또는 서버 거부 메시지
    @ViewBuilder
    private var inlineErrorSection: some View {
        if let message = inlineErrorDisplayMessage {
            Section {
                Text(message)
                    .appFont(.subheadline, color: Color.red500)
            }
        }
    }

    private var titleField: some View {
        TextField(
            "",
            text: titleBinding,
            prompt: Text("일정 제목")
                .foregroundStyle(Color.grey400)
        )
        .appFont(.body, color: Color.grey900)
        .submitLabel(.return)
        .tint(.indigo500)
    }

    private var allDayToggle: some View {
        Toggle(isOn: $viewModel.isAllDay) {
            Text("하루 종일")
                .appFont(.body, color: Color.grey900)
        }
        .tint(.indigo500)
    }

    /// 대면/비대면 토글 + 장소 선택 섹션
    private var placeSection: some View {
        Section {
            InPersonToggle(
                isInPerson: Binding(
                    get: { !viewModel.isOnline },
                    set: { viewModel.inPersonModeToggleChanged(to: $0) }
                )
            )

            if viewModel.isOnline {
                Text("비대면 일정은 장소가 자동으로 비워집니다")
                    .appFont(.footnote, color: Color.grey500)
            } else {
                PlaceSelectView(place: placeBinding)
            }
        }
    }

    @ViewBuilder
    private var scheduleDateTimeSection: some View {
        dateTimeRow(title: "시작", date: $viewModel.startDate, field: .start)
        dateTimeRow(title: "종료", date: $viewModel.endDate, field: .end)
    }

    /// 출석 정책 입력 섹션
    ///
    /// ponytail: `ScheduleCapabilities` 권한 조회를 이식하지 않아 토글을 항상 노출한다. 권한이
    /// 없는 사용자는 서버가 생성을 거부한다 — 권한 UseCase 이식 후 사전 차단으로 승격.
    @ViewBuilder
    private var attendancePolicySection: some View {
        if !viewModel.isAllDay {
            Section {
                Toggle(isOn: attendanceToggleBinding) {
                    Text("출석 필수")
                        .appFont(.body, color: Color.grey900)
                }
                .tint(.indigo500)

                if viewModel.isAttendanceRequired {
                    AttendancePolicyTimeSection(
                        checkInStartAt: $viewModel.attendanceCheckInStartAt,
                        onTimeEndAt: $viewModel.attendanceOnTimeEndAt,
                        lateEndAt: $viewModel.attendanceLateEndAt,
                        onTimesChanged: viewModel.attendanceTimesChanged
                    )

                    if let message = viewModel.attendancePolicyErrorMessage {
                        Text(message)
                            .appFont(.footnote, color: Color.red500)
                    }
                }
            }
        }
    }

    // ponytail: 참여자 선택은 SelectedChallengerView 가 ActivityPresentation internal 이라 제외
    // — 공용 승격 후 결선. 최대 초대 인원 표시도 참여자 섹션과 함께 빠졌다.

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if mode == .edit {
            ToolBarCollection.RejectBtn(action: {})

            ToolBarCollection.ConfirmBtn(
                action: { Task { await viewModel.updateSchedule() } },
                disable: isActionDisabled,
                isLoading: isSubmitting,
                // 성공(.loaded)을 확인한 뒤 닫아야 실패 시 입력이 살아 있다.
                dismissOnTap: false
            )
        } else {
            if isAIAvailable {
                ToolBarCollection.AddBtn(
                    imageSystemName: "sparkles",
                    action: { showAISheet = true }
                )
            }

            ToolBarCollection.AddBtn(
                action: { Task { await viewModel.submitSchedule() } },
                disable: isActionDisabled,
                isLoading: isSubmitting
            )
        }
    }

    // MARK: - Binding

    /// 제목 입력 바인딩. 입력마다 태그 자동 추천을 비동기로 갱신한다.
    private var titleBinding: Binding<String> {
        Binding(
            get: { viewModel.title },
            set: { newValue in
                viewModel.title = newValue
                Task { await viewModel.titleDidChange(to: newValue) }
            }
        )
    }

    private var tagBinding: Binding<[ScheduleIconCategory]> {
        Binding(
            get: { viewModel.tags },
            set: { viewModel.updateTagsFromUser($0) }
        )
    }

    private var attendanceToggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAttendanceRequired },
            set: { viewModel.attendanceToggleChanged(to: $0) }
        )
    }

    /// 장소 선택 UI 와 뷰모델을 잇는 바인딩.
    ///
    /// `PlaceSelection` 은 표시용 묶음이고 뷰모델은 도메인 모델(`ScheduleLocation`)을 들고 있어
    /// 여기서 한 번만 변환한다. 선택 해제(빈 이름)의 의미 부여는 뷰모델이 판단한다.
    private var placeBinding: Binding<PlaceSelection> {
        Binding(
            get: {
                guard let location = viewModel.placeLocation else { return .empty }
                return PlaceSelection(
                    name: location.locationName,
                    address: viewModel.placeAddress,
                    coordinate: CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                )
            },
            set: { selected in
                viewModel.placeSelectionChanged(
                    name: selected.name,
                    address: selected.address,
                    latitude: selected.coordinate.latitude,
                    longitude: selected.coordinate.longitude
                )
            }
        )
    }

    // MARK: - Helper

    private var navigationTitle: NavigationTitle.Activity {
        mode == .create ? .addSchedule : .editSchedule
    }

    private var isSubmitting: Bool {
        viewModel.submitState.isLoading
    }

    /// 저장 액션을 막아야 하는지 계산한다.
    ///
    /// 수정 모드는 필수값 충족에 더해 변경 사항 존재 여부와 이미 시작된 일정인지
    /// (SCHEDULE-0028 사전 차단)를 함께 확인한다.
    private var isActionDisabled: Bool {
        guard mode == .edit else {
            return !viewModel.canSubmit || isSubmitting
        }
        if viewModel.isEditingStartedSchedule { return true }
        return !viewModel.canSubmit || !viewModel.hasChangesInEditMode || isSubmitting
    }

    private var inlineErrorDisplayMessage: String? {
        if mode == .edit, viewModel.isEditingStartedSchedule {
            return "이미 시작된 일정은 수정할 수 없습니다."
        }
        return viewModel.inlineErrorMessage
    }

    private var isAIAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability {
            return true
        }
        return false
    }

    // MARK: - Function

    /// 시작/종료 한 행 + 펼쳐진 피커를 함께 그린다.
    @ViewBuilder
    private func dateTimeRow(
        title: String,
        date: Binding<Date>,
        field: ScheduleDateSlot.Field
    ) -> some View {
        let dateSlot = ScheduleDateSlot(field: field, component: .date)
        let timeSlot = ScheduleDateSlot(field: field, component: .time)

        DateTimeRow(
            title: title,
            date: date.wrappedValue,
            isAllDay: viewModel.isAllDay,
            isDatePickerActive: openScheduleSlot == dateSlot,
            isTimePickerActive: openScheduleSlot == timeSlot,
            dateTap: { toggleScheduleSlot(dateSlot) },
            timeTap: { toggleScheduleSlot(timeSlot) }
        )
        .equatable()

        if openScheduleSlot == dateSlot {
            DatePickerRow(date: date, range: pickerRange(for: field))
        }

        if openScheduleSlot == timeSlot {
            TimePickerRow(date: date, range: pickerRange(for: field))
        }
    }

    /// 종료 피커는 시작 시각 이전을 고를 수 없게 막는다.
    private func pickerRange(for field: ScheduleDateSlot.Field) -> ClosedRange<Date>? {
        field == .end ? viewModel.startDate...Date.distantFuture : nil
    }

    /// 같은 슬롯을 다시 누르면 접고, 다른 슬롯을 누르면 그쪽으로 옮긴다.
    private func toggleScheduleSlot(_ slot: ScheduleDateSlot) {
        withAnimation {
            openScheduleSlot = (openScheduleSlot == slot) ? nil : slot
        }
    }

    // MARK: - ScheduleDateSlot

    /// 시작/종료 일시에서 열려 있을 수 있는 피커 하나를 가리키는 식별자.
    fileprivate struct ScheduleDateSlot: Hashable {

        enum Field: Hashable {
            case start
            case end
        }

        enum Component: Hashable {
            case date
            case time
        }

        let field: Field
        let component: Component
    }
}

// MARK: - TagSelectionRow

/// 태그 선택 시트를 여는 행
private struct TagSelectionRow: View {

    // MARK: - Property

    @Binding var tagList: [ScheduleIconCategory]

    @State private var showTagList: Bool = false

    private enum Constants {
        static let title = "태그"
        static let chevron = "chevron.right"
    }

    // MARK: - Body

    var body: some View {
        Button {
            showTagList.toggle()
        } label: {
            HStack {
                Text(Constants.title)
                    .appFont(.body, color: Color.grey900)

                Spacer()

                selectedCount
            }
        }
        .sheet(isPresented: $showTagList) {
            TagListView(tagList: $tagList)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }

    private var selectedCount: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            if !tagList.isEmpty {
                Text("\(tagList.count)개 선택됨")
                    .appFont(.callout, color: Color.grey500)
            }

            Image(systemName: Constants.chevron)
                .foregroundStyle(Color.grey500)
        }
    }
}

// MARK: - MemoEditor

/// 메모 입력 에디터
private struct MemoEditor: View, Equatable {

    // MARK: - Property

    @Binding var memo: String

    private enum Constants {
        static let height: CGFloat = 200
        static let placeholder = "메모"
        static let placeholderPadding = EdgeInsets(top: 8, leading: 4, bottom: 8, trailing: 4)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.memo == rhs.memo
    }

    // MARK: - Body

    var body: some View {
        TextEditor(text: $memo)
            .overlay(alignment: .topLeading) {
                if memo.isEmpty {
                    Text(Constants.placeholder)
                        .appFont(.body, color: Color.grey400)
                        .padding(Constants.placeholderPadding)
                }
            }
            .frame(height: Constants.height)
    }
}

// MARK: - AIAutofillSheet

/// 자연어 입력으로 폼을 채워 주는 AI 자동완성 시트.
///
/// 성공하면 시트를 자동으로 닫아 채워진 폼을 바로 확인하게 한다. 장소는 이름만 제안하고 좌표는
/// 만들지 않으며, 출석 정책은 건드리지 않는다.
private struct AIAutofillSheet: View {

    // MARK: - Property

    @Bindable var viewModel: ScheduleRegistrationViewModel
    @Binding var isPresented: Bool

    private enum Constants {
        static let placeholder = "예: 다음 주 화요일 저녁 7시 스터디 모임 강남역 근처"
        static let buttonLabel = "AI로 정리"
        static let sheetTitle = "AI 자동완성"
        static let sheetDescription = "일정 내용을 자연어로 입력하면 AI가 폼을 자동으로 채웁니다."
        static let headerLabel = "Apple Intelligence"
        static let headerIconSize: CGFloat = 16
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                headerSection

                Text(Constants.sheetDescription)
                    .appFont(.subheadline, color: Color.grey600)
                    .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

                inputArea

                autofillButton

                usageFootnote

                Spacer()
            }
            .padding(.top, DefaultSpacing.spacing16)
            .navigationTitle(Constants.sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.resetAIAutofillState()
                        isPresented = false
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(Color.grey500)
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onChange(of: viewModel.aiAutofillState) {
            if case .loaded = viewModel.aiAutofillState {
                viewModel.resetAIAutofillState()
                isPresented = false
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "sparkles")
                .font(.system(size: Constants.headerIconSize, weight: .medium))
                .foregroundStyle(Color.indigo500)

            Text(Constants.headerLabel)
                .appFont(.callout, weight: .semibold, color: Color.grey700)
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    private var inputArea: some View {
        TextField(
            "",
            text: $viewModel.aiRawInput,
            prompt: Text(Constants.placeholder)
                .foregroundStyle(Color.grey400),
            axis: .vertical
        )
        .appFont(.body, color: Color.grey900)
        .lineLimit(3...6)
        .padding(DefaultSpacing.spacing12)
        .background(Color.grey100)
        .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    @ViewBuilder
    private var autofillButton: some View {
        Group {
            if viewModel.aiAutofillState.isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(.indigo500)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DefaultSpacing.spacing8)
            } else {
                Button {
                    Task { await viewModel.requestAIAutofill() }
                } label: {
                    Text(Constants.buttonLabel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.indigo500)
                .controlSize(.large)
                .disabled(isInputEmpty)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    @ViewBuilder
    private var usageFootnote: some View {
        if viewModel.aiCumulativeUsedTokens > 0 {
            Text("오늘 사용한 토큰 \(viewModel.aiCumulativeUsedTokens)")
                .appFont(.caption1, color: Color.grey500)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        }
    }

    private var isInputEmpty: Bool {
        viewModel.aiRawInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Preview

#if DEBUG
/// 네트워크 없이 화면을 확인하기 위한 프리뷰 전용 UseCase (절대규칙 #5)
private struct PreviewGenerateScheduleUseCase: GenerateScheduleUseCaseProtocol {
    @discardableResult
    func execute(request: ScheduleCreationRequest) async throws -> String { "1" }
}

private struct PreviewUpdateScheduleUseCase: UpdateScheduleUseCaseProtocol {
    func execute(scheduleId: String, request: ScheduleUpdateRequest) async throws {}
}

private struct PreviewClassifyScheduleUseCase: ClassifyScheduleUseCaseProtocol {
    func execute(title: String) async -> ScheduleIconCategory { .study }
}

#Preview("ScheduleRegistrationView") {
    let container = DIContainer()
    container.register(GenerateScheduleUseCaseProtocol.self) {
        PreviewGenerateScheduleUseCase()
    }
    container.register(UpdateScheduleUseCaseProtocol.self) {
        PreviewUpdateScheduleUseCase()
    }
    container.register(ClassifyScheduleUseCaseProtocol.self) {
        PreviewClassifyScheduleUseCase()
    }

    return NavigationStack {
        ScheduleRegistrationView(container: container)
    }
    .environment(ErrorHandler())
}
#endif
