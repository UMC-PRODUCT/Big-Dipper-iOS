//
//  RegistrationView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/22/26.
//

import SwiftUI

/// 일정 생성 화면
///
/// 새로운 일정을 생성하거나 기존 일정을 편집할 때 사용되는 화면입니다.
/// 제목, 장소, 날짜, 시간, 참여자, 태그, 메모 등의 정보를 입력받습니다.
struct ScheduleRegistrationView: View {

    // MARK: - Property

    /// 일정 등록 뷰 모델
    @State var viewModel: ScheduleRegistrationViewModel

    @Environment(\.dismiss) var dismiss

    /// 현재 로그인 사용자의 역할입니다.
    @AppStorage(AppStorageKey.memberRole) private var memberRole: ManagementTeam = .challenger
    /// 운영진 생성 플로우에서 출석부 생성 여부 확인 다이얼로그 표시 상태입니다.
    @State private var showApprovalConfirmationDialog: Bool = false
    /// 화면이 생성 모드인지 수정 모드인지 구분합니다.
    private let mode: Mode

    /// 일정 등록 화면의 동작 모드입니다.
    enum Mode {
        case create
        case edit
    }

    // MARK: - Initializer

    /// 일정 등록 화면을 초기화합니다.
    ///
    /// 수정 모드에서는 `prefill` 값을 즉시 반영해 기존 일정을 편집 가능한 상태로 구성합니다.
    ///
    /// - Parameters:
    ///   - container: Home Feature 의존성을 조립한 `DIContainer`입니다.
    ///   - errorHandler: 화면에서 사용할 전역 `ErrorHandler`입니다.
    ///   - mode: 화면의 동작 모드입니다.
    ///   - prefill: 수정 모드에서 사용할 기존 일정 정보입니다.
    ///   - prefillRoadAddress: 장소 프리필 시 우선 노출할 도로명 주소입니다.
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        mode: Mode = .create,
        prefill: ScheduleDetailData? = nil,
        prefillRoadAddress: String? = nil
    ) {
        self.mode = mode
        let viewModel = ScheduleRegistrationViewModel(
            container: container,
            errorHandler: errorHandler
        )
        if let prefill {
            viewModel.applyPrefill(from: prefill, roadAddress: prefillRoadAddress)
        }
        self._viewModel = .init(wrappedValue: viewModel)
    }
    
    // MARK: - Body

    /// 일정 등록 폼과 상단 툴바를 조합한 화면 본문입니다.
    var body: some View {
        formContent
            .scrollDismissesKeyboard(.immediately)
            .navigation(naviTitle: navigationTitle, displayMode: .inline)
            .toolbar { toolbarContent }
            .modifier(KeyboardDismissOnPickerToggle(viewModel: viewModel))
            .onChange(of: viewModel.submitState) {
                if case .loaded = viewModel.submitState {
                    dismiss()
                }
            }
            .task {
                if mode == .edit {
                    await viewModel.fetchPrefillParticipants()
                }
                await viewModel.loadCapabilities()
            }
            .onChange(of: viewModel.dataRange.startDate) {
                viewModel.prefillAttendancePolicyIfNeeded()
            }
            .onChange(of: viewModel.isAllDay) {
                viewModel.prefillAttendancePolicyIfNeeded()
            }
    }

    // MARK: - Private Function

    /// 입력 섹션을 순서대로 배치한 기본 폼입니다.
    private var formContent: some View {
        Form {
            inlineErrorSection
            section(.title)
            placeSection
            section(.allDay, .date)
            AttendancePolicySection(viewModel: viewModel)
            section(.participation)
            section(.tag)
            section(.memo)
        }
        .alertPrompt(item: $viewModel.alertPrompt)
    }

    /// 대면/비대면 토글과 장소 선택을 묶은 섹션입니다.
    private var placeSection: some View {
        Section {
            InPersonToggle(
                isInPerson: Binding(
                    get: { !viewModel.isOnline },
                    set: { viewModel.inPersonModeToggleChanged(to: $0) }
                )
            )

            if !viewModel.isOnline {
                PlaceSelectView(place: $viewModel.place)
            } else {
                Text("비대면 일정은 장소가 자동으로 비워집니다")
                    .appFont(.footnote, color: .grey500)
            }
        }
    }

    /// 수정 모드에서 시작된 일정 가드 또는 서버 에러 메시지를 노출하는 섹션입니다.
    @ViewBuilder
    private var inlineErrorSection: some View {
        if let message = inlineErrorDisplayMessage {
            Section {
                Text(message)
                    .appFont(.subheadline, color: .red500)
            }
        }
    }

    /// 화면에 표시할 인라인 에러 메시지입니다.
    ///
    /// 수정 모드에서 이미 시작된 일정인 경우 가드 메시지를 우선 노출하고,
    /// 그 외에는 ViewModel 이 보유한 서버 에러 메시지를 그대로 보여줍니다.
    private var inlineErrorDisplayMessage: String? {
        if mode == .edit, viewModel.isEditingStartedSchedule {
            return "이미 시작된 일정은 수정할 수 없습니다."
        }
        return viewModel.inlineErrorMessage
    }

    /// 모드에 따라 상단 툴바 구성을 분기합니다.
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if mode == .edit {
            ToolBarCollection.RejectBtn(action: {})
            ToolBarCollection.ConfirmBtn(
                action: {
                    Task {
                        await viewModel.updateSchedule()
                    }
                },
                disable: isActionDisabled,
                isLoading: isSubmitting,
                dismissOnTap: false,
            )
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                createToolbarButton
            }
        }
    }

    // MARK: - Helper

    /// 현재 모드에 맞는 내비게이션 타이틀입니다.
    private var navigationTitle: NavigationModifier.Navititle {
        mode == .create ? .registration : .registrationEdit
    }

    /// 생성 모드에서 노출되는 우측 상단 추가 버튼입니다.
    ///
    /// 로딩 중에는 아이콘 대신 `ProgressView`를 노출하고, 운영진인 경우
    /// 탭 시 출석부 생성 여부를 확인하는 `confirmationDialog`를 띄웁니다.
    private var createToolbarButton: some View {
        Button {
            guard !isActionDisabled, !isSubmitting else { return }
            submitCreateAction()
        } label: {
            ZStack {
                Image(systemName: "plus")
                    .opacity(isSubmitting ? 0 : 1)

                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.indigo500)
                }
            }
        }
        .tint((isActionDisabled || isSubmitting) ? .grey300 : .indigo500)
        .disabled(isActionDisabled || isSubmitting)
        .confirmationDialog(
            "일정 생성",
            isPresented: $showApprovalConfirmationDialog,
            titleVisibility: .visible
        ) {
            approvalConfirmationActions()
        } message: {
            approvalConfirmationMessage()
        }
    }

    /// 운영진 생성 플로우에서 표시할 확인 다이얼로그 액션 목록입니다.
    ///
    /// V2 마이그레이션 이후 출석 정책 입력 UI 가 분리될 때까지 두 선택지 모두
    /// 동일하게 출석 정책 없이 일정을 생성합니다.
    @ViewBuilder
    private func approvalConfirmationActions() -> some View {
        if memberRole != .challenger {
            Button("출석부 생성합니다", role: .destructive) {
                Task {
                    await viewModel.submitSchedule()
                }
            }

            Button("일정만 생성할게요") {
                Task {
                    await viewModel.submitSchedule()
                }
            }
        }
    }

    /// 출석부 생성 여부를 묻는 확인 다이얼로그 안내 문구입니다.
    @ViewBuilder
    private func approvalConfirmationMessage() -> some View {
        if memberRole != .challenger {
            Text("출석을 체크하시겠습니까?")
        }
    }

    /// 일정 생성 또는 수정 요청이 진행 중인지 여부입니다.
    private var isSubmitting: Bool {
        if case .loading = viewModel.submitState {
            return true
        }
        return false
    }

    /// 현재 입력 상태에서 저장 액션을 비활성화해야 하는지 계산합니다.
    ///
    /// 생성 모드는 필수값 충족 여부만 확인하고, 수정 모드는 변경 사항 존재 여부와
    /// 이미 시작된 일정인지(SCHEDULE-0028 사전 차단) 여부를 함께 확인합니다.
    private var isActionDisabled: Bool {
        if mode == .edit {
            if viewModel.isEditingStartedSchedule { return true }
            return !viewModel.canSubmit || !viewModel.hasChangesInEditMode || isSubmitting
        }
        return !viewModel.canSubmit || isSubmitting
    }

    /// 전달된 섹션 타입 배열을 하나의 `Section`으로 묶어 렌더링합니다.
    ///
    /// - Parameter types: 동일 섹션에 포함할 `ScheduleGenerationType` 목록입니다.
    @ViewBuilder
    private func section(_ types: ScheduleGenerationType...) -> some View {
        Section {
            ForEach(types, id: \.self) { type in
                sectionView(type)
            }
        }
    }

    // MARK: - Function

    /// 생성 모드의 추가 버튼 탭 동작을 처리합니다.
    ///
    /// 챌린저는 출석부 없이 바로 일정을 생성하고, 운영진은 출석부 동시 생성 여부를 먼저 확인합니다.
    private func submitCreateAction() {
        if memberRole == .challenger {
            Task {
                await viewModel.submitSchedule()
            }
        } else {
            showApprovalConfirmationDialog = true
        }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }

    // MARK: - Section Components
    
    /// 섹션 타입에 대응하는 입력 뷰를 반환합니다.
    ///
    /// - Parameter type: 일정 생성 화면의 섹션 타입입니다.
    @ViewBuilder
    private func sectionView(_ type: ScheduleGenerationType) -> some View {
        switch type {
        case .title:
            TitleView(
                text: Binding(
                    get: { viewModel.title },
                    set: { newValue in
                        viewModel.title = newValue
                        Task { @MainActor in
                            await viewModel.titleDidChange(to: newValue)
                        }
                    }
                )
            )
                .equatable()
        case .place:
            PlaceSelectView(place: $viewModel.place)
        case .allDay:
            AllDayToggle(isOn: $viewModel.isAllDay)
        case .date:
            DateTimeSection(
                isAllDay: $viewModel.isAllDay,
                startDate: $viewModel.dataRange.startDate,
                endDate: $viewModel.dataRange.endDate,
                showStartDatePicker: $viewModel.showStartDatePicker,
                showStartTimePicker: $viewModel.showStartTimePicker,
                showEndDatePicker: $viewModel.showEndDatePicker,
                showEndTimePicker: $viewModel.showEndTimePicker
            )
        case .memo:
            Memo(memo: $viewModel.memo)
                .equatable()
        case .participation:
            ParticipantSection(
                challenger: $viewModel.participatn,
                maxParticipantCount: {
                    guard case .loaded(let caps) = viewModel.capabilitiesState else { return nil }
                    return caps.maxParticipantCount
                }()
            )
        case .tag:
            TagSection(
                tag: Binding(
                    get: { viewModel.tag },
                    set: { newValue in
                        viewModel.updateTagsFromUser(newValue)
                    }
                )
            )
        }
    }

}

// MARK: - Subviews

/// 일정 제목을 입력받는 서브 뷰입니다.
fileprivate struct TitleView: View, Equatable {
    /// 입력된 제목 텍스트 (바인딩)
    @Binding var text: String
    
    /// 값 변경 감지를 위한 Equatable 프로토콜 구현
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.text == rhs.text
    }
    
    var body: some View {
        TextField("", text: $text, prompt: placeholder)
            .submitLabel(.return)
            .tint(.indigo500)
            .appFont(.body, color: .black)
    }
    
    /// 플레이스홀더 텍스트 뷰
    private var placeholder: Text {
        Text(ScheduleGenerationType.title.placeholder ?? "")
            .font(ScheduleGenerationType.title.placeholderFont)
            .foregroundStyle(ScheduleGenerationType.title.placeholderColor)
    }
}

// MARK: - In-Person Toggle

/// "대면 일정" 설정 토글 뷰
///
/// `isInPerson == true` 이면 대면(장소 입력 필수), `false` 이면 비대면.
/// ViewModel의 `isOnline` 과 의미가 반전되어 있으므로 inverse binding 으로 연결합니다.
fileprivate struct InPersonToggle: View, Equatable {
    @Binding var isInPerson: Bool

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isInPerson == rhs.isInPerson
    }

    var body: some View {
        Toggle(isOn: $isInPerson) {
            Text("대면 일정")
                .appFont(.body, color: .black)
        }
        .tint(.indigo500)
    }
}

// MARK: - All Day Toggle

/// "하루 종일" 설정 토글 뷰
fileprivate struct AllDayToggle: View, Equatable {
    /// 토글 상태 바인딩
    @Binding var isOn: Bool
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.isOn == rhs.isOn
    }
    
    var body: some View {
        Toggle(isOn: $isOn) {
            Text(ScheduleGenerationType.allDay.placeholder ?? "")
                .appFont(.body, color: .black)
        }
        .tint(.indigo500)
    }
}


// MARK: - DateTime Section

/// 시작/종료 날짜 및 시간 선택 섹션
///
/// 시작 날짜/시간 행과 종료 날짜/시간 행, 그리고 각각의 Picker를 포함합니다.
fileprivate struct DateTimeSection: View {
    
    // MARK: - Property
    
    @Binding var isAllDay: Bool
    @Binding var startDate: Date
    @Binding var endDate: Date
    
    /// 하나의 Picker만 열리도록 상위 화면에서 제어하는 표시 상태 바인딩입니다.
    @Binding var showStartDatePicker: Bool
    @Binding var showStartTimePicker: Bool
    @Binding var showEndDatePicker: Bool
    @Binding var showEndTimePicker: Bool
    
    // MARK: - Body

    var body: some View {
        Group {
            startDateRow
            generateDatePicker(condition: showStartDatePicker, date: $startDate)
            generateTimePicker(condition: showStartTimePicker, date: $startDate)
            endDateRow
            generateDatePicker(
                condition: showEndDatePicker,
                date: $endDate,
                minimumDate: startDate
            )
            generateTimePicker(
                condition: showEndTimePicker,
                date: $endDate,
                minimumDate: startDate
            )
        }
        .onChange(of: startDate) { _, newValue in
            if endDate < newValue {
                endDate = newValue
            }
        }
        .onChange(of: endDate) { _, newValue in
            if newValue < startDate {
                endDate = startDate
            }
        }
    }
    
    // MARK: - Helper

    /// 시작 날짜/시간 표시 행
    private var startDateRow: some View {
        DateTimeRow(
            title: "시작",
            date: startDate,
            isAllDay: isAllDay,
            isDatePickerActive: showStartDatePicker,
            isTimePickerActive: showStartTimePicker,
            dateTap: {
                withAnimation {
                    showStartDatePicker.toggle()
                    showStartTimePicker = false
                    showEndDatePicker = false
                    showEndTimePicker = false
                }
            },
            timeTap: {
                withAnimation {
                    showStartTimePicker.toggle()
                    showStartDatePicker = false
                    showEndDatePicker = false
                    showEndTimePicker = false
                }
            }
        )
        .equatable()
    }
    
    /// 종료 날짜/시간 표시 행
    private var endDateRow: some View {
        DateTimeRow(
            title: "종료",
            date: endDate,
            isAllDay: isAllDay,
            isDatePickerActive: showEndDatePicker,
            isTimePickerActive: showEndTimePicker,
            dateTap: {
                withAnimation {
                    showEndDatePicker.toggle()
                    showStartDatePicker = false
                    showStartTimePicker = false
                    showEndTimePicker = false
                }
            },
            timeTap: {
                withAnimation {
                    showEndTimePicker.toggle()
                    showStartDatePicker = false
                    showStartTimePicker = false
                    showEndDatePicker = false
                }
            }
        )
        .equatable()
    }
    
    /// 날짜 선택 피커 생성
    @ViewBuilder
    private func generateDatePicker(
        condition: Bool,
        date: Binding<Date>,
        minimumDate: Date? = nil
    ) -> some View {
        if condition {
            if let minimumDate {
                DatePickerRow(
                    date: date,
                    range: minimumDate...Date.distantFuture
                )
            } else {
                DatePickerRow(date: date, range: nil)
            }
        }
    }
    
    /// 시간 선택 피커 생성
    @ViewBuilder
    private func generateTimePicker(
        condition: Bool,
        date: Binding<Date>,
        minimumDate: Date? = nil
    ) -> some View {
        if condition {
            if let minimumDate {
                TimePickerRow(
                    date: date,
                    range: minimumDate...Date.distantFuture
                )
            } else {
                TimePickerRow(date: date, range: nil)
            }
        }
    }
}

// MARK: - Tag Section

/// 태그 선택 섹션 (아이콘 선택 등)
fileprivate struct TagSection: View {
    
    /// 선택된 태그 리스트 바인딩
    @Binding var tag: [ScheduleIconCategory]
    
    /// 태그 선택 시트 표시 여부
    @State private var showTagList: Bool = false
  
    private enum Constants {
        static let tagText: String = "태그"
        static let chevronImage: String = "chevron.right"
    }
    
    var body: some View {
        Button {
            showTagList.toggle()
        } label: {
            HStack {
                Text(Constants.tagText)
                    .foregroundStyle(.black)
                Spacer()
                tagCount
            }
        }
        .sheet(isPresented: $showTagList) {
            TagListView(tagList: $tag)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
        }
    }
    
    /// 선택된 태그 개수 표시
    private var tagCount: some View {
        HStack(spacing: DefaultSpacing.spacing8, content: {
            if !tag.isEmpty {
                Text("\(tag.count)개 선택됨")
                    .appFont(.callout, color: .grey500)
            }
            
            Image(systemName: Constants.chevronImage)
                .foregroundStyle(.grey500)
        })
    }
}

// MARK: - Participant Section

/// 참여자(챌린저) 선택 및 관리 섹션
fileprivate struct ParticipantSection: View {

    /// 선택된 참여자 리스트 바인딩
    @Binding var challenger: [ChallengerInfo]

    /// 최대 초대 가능 인원 (`nil` = 제한 없음)
    let maxParticipantCount: Int?

    /// 참여자 선택 시트 표시 여부
    @State private var showParticipantSheet: Bool = false

    private enum Constants {
        static let challengerText: String = "초대받은 챌린저"
        static let chevronImage: String = "chevron.right"
    }

    private var isAtCapacity: Bool {
        guard let max = maxParticipantCount else { return false }
        return challenger.count >= max
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Button {
                showParticipantSheet.toggle()
            } label: {
                HStack {
                    Text(Constants.challengerText)
                        .foregroundStyle(.black)
                    Spacer()
                    participant
                }
            }
            .disabled(isAtCapacity)
            .sheet(isPresented: $showParticipantSheet) {
                SelectedChallengerView(challenger: $challenger)
                    .interactiveDismissDisabled()
            }

            if let max = maxParticipantCount, isAtCapacity {
                Text("최대 \(max)명까지 추가할 수 있습니다")
                    .appFont(.caption1, color: .grey500)
            }
        }
    }

    /// 선택된 참여자 수 (및 상한 도달 시 카운터) 표시
    private var participant: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            if let max = maxParticipantCount {
                Text("\(challenger.count) / \(max)")
                    .appFont(.footnote, color: isAtCapacity ? .red : .grey600)
            } else if !challenger.isEmpty {
                Text("\(challenger.count)명")
                    .appFont(.callout, color: .grey500)
            }

            Image(systemName: Constants.chevronImage)
                .foregroundStyle(isAtCapacity ? Color.grey400 : Color.grey500)
        }
    }
}

// MARK: - Keyboard Dismiss On Picker Toggle

/// 일정 / 출석 정책의 모든 picker 토글과 `isAllDay` 변경 시 키보드를 내리는 ViewModifier.
///
/// `body` 의 `.onChange` 체인이 길어져 컴파일러 type-check 가 타임아웃되는 문제를 회피하기 위해
/// 별도 `ViewModifier` 로 분리했습니다.
fileprivate struct KeyboardDismissOnPickerToggle: ViewModifier {

    let viewModel: ScheduleRegistrationViewModel

    func body(content: Content) -> some View {
        content
            .onChange(of: viewModel.showStartDatePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showStartTimePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showEndDatePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showEndTimePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showCheckInStartDatePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showCheckInStartTimePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showOnTimeEndDatePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showOnTimeEndTimePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showLateEndDatePicker) { dismissKeyboard() }
            .onChange(of: viewModel.showLateEndTimePicker) { dismissKeyboard() }
            .onChange(of: viewModel.isAllDay) { dismissKeyboard() }
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

// MARK: - Attendance Policy Time Section

/// 출석 정책 3개 시각(체크인 시작 / 정시 종료 / 지각 종료) 입력 섹션입니다.
///
/// `DateTimeRow` 패턴을 그대로 재사용하며, 시각 변경 시 `onTimesChanged` 콜백으로
/// ViewModel 의 dirty flag 토글과 검증 갱신을 트리거합니다.
fileprivate struct AttendancePolicyTimeSection: View {

    @Binding var checkInStartAt: Date
    @Binding var onTimeEndAt: Date
    @Binding var lateEndAt: Date

    @Binding var showCheckInDatePicker: Bool
    @Binding var showCheckInTimePicker: Bool
    @Binding var showOnTimeDatePicker: Bool
    @Binding var showOnTimeTimePicker: Bool
    @Binding var showLateDatePicker: Bool
    @Binding var showLateTimePicker: Bool

    let onTimesChanged: () -> Void

    var body: some View {
        Group {
            row(
                title: "체크인 시작",
                date: $checkInStartAt,
                isDateActive: showCheckInDatePicker,
                isTimeActive: showCheckInTimePicker,
                dateTap: {
                    withAnimation {
                        showCheckInDatePicker.toggle()
                        closeOthers(except: .checkInDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showCheckInTimePicker.toggle()
                        closeOthers(except: .checkInTime)
                    }
                }
            )
            picker(condition: showCheckInDatePicker, date: $checkInStartAt, isTime: false)
            picker(condition: showCheckInTimePicker, date: $checkInStartAt, isTime: true)

            row(
                title: "정시 종료",
                date: $onTimeEndAt,
                isDateActive: showOnTimeDatePicker,
                isTimeActive: showOnTimeTimePicker,
                dateTap: {
                    withAnimation {
                        showOnTimeDatePicker.toggle()
                        closeOthers(except: .onTimeDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showOnTimeTimePicker.toggle()
                        closeOthers(except: .onTimeTime)
                    }
                }
            )
            picker(condition: showOnTimeDatePicker, date: $onTimeEndAt, isTime: false)
            picker(condition: showOnTimeTimePicker, date: $onTimeEndAt, isTime: true)

            row(
                title: "지각 종료",
                date: $lateEndAt,
                isDateActive: showLateDatePicker,
                isTimeActive: showLateTimePicker,
                dateTap: {
                    withAnimation {
                        showLateDatePicker.toggle()
                        closeOthers(except: .lateDate)
                    }
                },
                timeTap: {
                    withAnimation {
                        showLateTimePicker.toggle()
                        closeOthers(except: .lateTime)
                    }
                }
            )
            picker(condition: showLateDatePicker, date: $lateEndAt, isTime: false)
            picker(condition: showLateTimePicker, date: $lateEndAt, isTime: true)
        }
        .onChange(of: checkInStartAt) { onTimesChanged() }
        .onChange(of: onTimeEndAt) { onTimesChanged() }
        .onChange(of: lateEndAt) { onTimesChanged() }
    }

    /// 단일 시각 입력 행
    private func row(
        title: String,
        date: Binding<Date>,
        isDateActive: Bool,
        isTimeActive: Bool,
        dateTap: @escaping () -> Void,
        timeTap: @escaping () -> Void
    ) -> some View {
        DateTimeRow(
            title: title,
            date: date.wrappedValue,
            isAllDay: false,
            isDatePickerActive: isDateActive,
            isTimePickerActive: isTimeActive,
            dateTap: dateTap,
            timeTap: timeTap
        )
        .equatable()
    }

    /// 날짜 또는 시간 피커
    @ViewBuilder
    private func picker(condition: Bool, date: Binding<Date>, isTime: Bool) -> some View {
        if condition {
            if isTime {
                TimePickerRow(date: date, range: nil)
            } else {
                DatePickerRow(date: date, range: nil)
            }
        }
    }

    /// 한 번에 하나의 picker 만 열리도록 다른 picker 들을 닫습니다.
    private func closeOthers(except keep: PickerSlot) {
        if keep != .checkInDate { showCheckInDatePicker = false }
        if keep != .checkInTime { showCheckInTimePicker = false }
        if keep != .onTimeDate { showOnTimeDatePicker = false }
        if keep != .onTimeTime { showOnTimeTimePicker = false }
        if keep != .lateDate { showLateDatePicker = false }
        if keep != .lateTime { showLateTimePicker = false }
    }

    /// 현재 활성 picker 슬롯 식별자
    private enum PickerSlot {
        case checkInDate, checkInTime, onTimeDate, onTimeTime, lateDate, lateTime
    }
}

// MARK: - Attendance Policy Section

/// 출석 정책 입력 섹션 (운영진 전용, 비-하루종일 일정 한정).
///
/// `canCreateAttendanceRequiredSchedule` 권한과 `isAllDay == false` 가 모두 충족될 때만
/// 노출되며, 토글 ON 시 3개 시각 행과 인라인 검증 에러를 표시합니다.
fileprivate struct AttendancePolicySection: View {

    @Bindable var viewModel: ScheduleRegistrationViewModel

    var body: some View {
        if shouldShowSection {
            Section {
                Toggle(isOn: toggleBinding) {
                    Text("출석 필수")
                        .appFont(.body, color: .black)
                }
                .tint(.indigo500)

                if viewModel.isAttendanceRequired {
                    AttendancePolicyTimeSection(
                        checkInStartAt: $viewModel.attendanceCheckInStartAt,
                        onTimeEndAt: $viewModel.attendanceOnTimeEndAt,
                        lateEndAt: $viewModel.attendanceLateEndAt,
                        showCheckInDatePicker: $viewModel.showCheckInStartDatePicker,
                        showCheckInTimePicker: $viewModel.showCheckInStartTimePicker,
                        showOnTimeDatePicker: $viewModel.showOnTimeEndDatePicker,
                        showOnTimeTimePicker: $viewModel.showOnTimeEndTimePicker,
                        showLateDatePicker: $viewModel.showLateEndDatePicker,
                        showLateTimePicker: $viewModel.showLateEndTimePicker,
                        onTimesChanged: {
                            viewModel.attendanceTimesChanged()
                        }
                    )

                    if let message = viewModel.attendancePolicyError?.message {
                        Text(message)
                            .appFont(.footnote, color: .red500)
                    }
                }
            } header: {
                Text("출석 체크")
            }
        }
    }

    /// 권한 + 비-하루종일 조건이 모두 충족됐는지 여부.
    private var shouldShowSection: Bool {
        guard !viewModel.isAllDay else { return false }
        guard case .loaded(let caps) = viewModel.capabilitiesState else { return false }
        return caps.canCreateAttendanceRequiredSchedule
    }

    /// 토글 변경 시 ViewModel 의 dirty/prefill 처리를 함께 트리거하는 바인딩.
    private var toggleBinding: Binding<Bool> {
        Binding(
            get: { viewModel.isAttendanceRequired },
            set: { newValue in
                viewModel.attendanceToggleChanged(to: newValue)
            }
        )
    }
}

// MARK: - Memo Section

/// 메모 입력 섹션 (TextEditor)
fileprivate struct Memo: View, Equatable {
    /// 입력된 메모 텍스트 바인딩
    @Binding var memo: String
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.memo == rhs.memo
    }
    
    private enum Constants {
        static let textEditorHeight: CGFloat = 200
        static let placeholderPadding: EdgeInsets = .init(top: 8, leading: 4, bottom: 8, trailing: 4)
    }
    
    var body: some View {
        TextEditor(text: $memo)
            .overlay(alignment: .topLeading) {
                if memo.isEmpty {
                    Text(ScheduleGenerationType.memo.placeholder ?? "")
                        .font(ScheduleGenerationType.memo.placeholderFont)
                        .foregroundStyle(ScheduleGenerationType.memo.placeholderColor)
                        .padding(Constants.placeholderPadding)
                }
            }
            .frame(height: Constants.textEditorHeight)
    }
}
