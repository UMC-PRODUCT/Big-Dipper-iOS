//
//  StudyScheduleRegistrationView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreLocation
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 스터디 일정 등록 화면.
///
/// 스터디 그룹 카드의 "일정 등록" 을 탭하면 푸시된다. 스터디명·주차 커리큘럼·일시·출석
/// 정책·장소를 입력받아 일정 생성과 스터디 그룹 연결 두 단계를 뷰모델에 위임한다.
///
/// `navigationDestination` 으로 실리므로 자체 `NavigationStack` 을 만들지 않는다.
struct StudyScheduleRegistrationView: View {

    // MARK: - Property

    @Bindable private var viewModel: StudyScheduleRegistrationViewModel
    @Environment(\.dismiss) private var dismiss

    /// 현재 펼쳐진 시작/종료 피커. `nil` 이면 모두 접힌 상태다.
    ///
    /// 어느 피커가 열려 있는지는 이 화면 밖에서 의미가 없어 뷰가 소유한다. 슬롯 하나로
    /// 들고 있으므로 두 피커가 동시에 열리는 상태를 표현할 수 없다.
    @State private var openScheduleSlot: ScheduleDateSlot?

    // MARK: - Initializer

    /// - Parameter viewModel: 일정 등록 상태를 관리하는 뷰 모델
    init(viewModel: StudyScheduleRegistrationViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        Form {
            Section {
                studyNameField
            }

            Section("주차 커리큘럼") {
                weeklyCurriculumPicker
            }

            Section("일시") {
                scheduleDateTimeSection
            }

            Section("출석 정책") {
                attendancePolicySection
            }

            placeSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigation(
            naviTitle: NavigationTitle.Activity.studyScheduleRegistration,
            displayMode: .inline
        )
        .toolbar {
            ToolBarCollection.ConfirmBtn(
                action: submitSchedule,
                disable: !viewModel.canSubmit,
                isLoading: viewModel.isSubmitting,
                // 등록은 두 단계라 성공 여부가 확정된 뒤에 닫아야 한다.
                dismissOnTap: false
            )
        }
        .alertPrompt(item: $viewModel.alertPrompt)
        .task {
            async let weekly: Void = viewModel.loadWeeklyOptions()
            async let participants: Void = viewModel.loadParticipantMembers()
            _ = await (weekly, participants)
        }
        .onChange(of: viewModel.startDate) {
            viewModel.prefillAttendancePolicyIfNeeded()
        }
    }

    // MARK: - Sections

    /// 스터디명 입력 필드
    private var studyNameField: some View {
        TextField(
            "",
            text: $viewModel.studyName,
            prompt: Text("스터디명")
                .foregroundStyle(Color.grey400)
        )
        .appFont(.body, color: Color.grey900)
        .submitLabel(.next)
        .tint(.indigo500)
    }

    /// 주차 커리큘럼 선택 Picker
    @ViewBuilder
    private var weeklyCurriculumPicker: some View {
        switch viewModel.weeklyOptionsState {
        case .idle, .loading:
            HStack {
                Text("주차 목록 불러오는 중…")
                    .appFont(.body, color: Color.grey500)
                Spacer()
                ProgressView()
            }

        case .failed:
            HStack {
                Text("주차 목록을 불러오지 못했어요")
                    .appFont(.body, color: Color.grey500)
                Spacer()
                Button("재시도") {
                    Task { await viewModel.loadWeeklyOptions() }
                }
                .appFont(.footnote, color: Color.indigo500)
            }

        case .loaded(let options) where options.isEmpty:
            Text("등록된 주차 커리큘럼이 없어요")
                .appFont(.body, color: Color.grey500)

        case .loaded(let options):
            Picker("주차 커리큘럼", selection: $viewModel.selectedWeeklyOption) {
                ForEach(options) { option in
                    Text("\(option.weekNo)주차 · \(option.title)")
                        .tag(Optional(option))
                }
            }
            .pickerStyle(.menu)
            .tint(.indigo500)
        }
    }

    /// 시작/종료 일시 선택 섹션
    @ViewBuilder
    private var scheduleDateTimeSection: some View {
        dateTimeRow(title: "시작", date: $viewModel.startDate, field: .start)
        dateTimeRow(title: "종료", date: $viewModel.endDate, field: .end)
    }

    /// 출석 정책 3개 시각 입력 + 인라인 검증 에러
    @ViewBuilder
    private var attendancePolicySection: some View {
        AttendancePolicyTimeSection(
            checkInStartAt: $viewModel.attendanceCheckInStartAt,
            onTimeEndAt: $viewModel.attendanceOnTimeEndAt,
            lateEndAt: $viewModel.attendanceLateEndAt,
            onTimesChanged: viewModel.attendanceTimesChanged
        )

        if let message = viewModel.attendancePolicyError?.message {
            Text(message)
                .appFont(.footnote, color: Color.red500)
        }
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
                Text("비대면 스터디는 장소가 자동으로 비워집니다")
                    .appFont(.footnote, color: Color.grey500)
            } else {
                PlaceSelectView(place: placeBinding)
            }
        }
    }

    // MARK: - Function

    /// 장소 선택 UI 와 뷰모델을 잇는 바인딩.
    ///
    /// `PlaceSelection` 은 표시용 묶음이고 뷰모델은 이름·주소·좌표를 각각 들고 있어, 여기서
    /// 한 번만 변환한다. 선택 해제(빈 이름)의 의미 부여는 뷰모델이 판단한다.
    private var placeBinding: Binding<PlaceSelection> {
        Binding(
            get: {
                guard let coordinate = viewModel.placeCoordinate else { return .empty }
                return PlaceSelection(
                    name: viewModel.placeName,
                    address: viewModel.placeAddress,
                    coordinate: CLLocationCoordinate2D(
                        latitude: coordinate.latitude,
                        longitude: coordinate.longitude
                    )
                )
            },
            set: { selected in
                viewModel.placeSelectionChanged(
                    name: selected.name,
                    address: selected.address,
                    coordinate: Coordinate(
                        latitude: selected.coordinate.latitude,
                        longitude: selected.coordinate.longitude
                    )
                )
            }
        )
    }

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
            isAllDay: false,
            isDatePickerActive: openScheduleSlot == dateSlot,
            isTimePickerActive: openScheduleSlot == timeSlot,
            dateTap: { toggleScheduleSlot(dateSlot) },
            timeTap: { toggleScheduleSlot(timeSlot) }
        )
        .equatable()

        if openScheduleSlot == dateSlot {
            DatePickerRow(date: date)
        }

        if openScheduleSlot == timeSlot {
            TimePickerRow(date: date)
        }
    }

    /// 같은 슬롯을 다시 누르면 접고, 다른 슬롯을 누르면 그쪽으로 옮긴다.
    private func toggleScheduleSlot(_ slot: ScheduleDateSlot) {
        withAnimation {
            openScheduleSlot = (openScheduleSlot == slot) ? nil : slot
        }
    }

    /// 등록 요청. 중복 제출 방지는 뷰모델의 ``isSubmitting`` 이 단독으로 담당한다.
    private func submitSchedule() {
        Task {
            if await viewModel.submitSchedule() {
                dismiss()
            }
        }
    }

    // MARK: - ScheduleDateSlot

    /// 시작/종료 일시에서 열려 있을 수 있는 피커 하나를 가리키는 식별자.
    fileprivate struct ScheduleDateSlot: Hashable {

        /// 일정의 시작/종료 중 하나
        enum Field: Hashable {
            case start
            case end
        }

        /// 같은 일시를 편집하는 두 피커 중 하나
        enum Component: Hashable {
            case date
            case time
        }

        let field: Field
        let component: Component
    }
}

// MARK: - Preview

#if DEBUG
#Preview("StudyScheduleRegistrationView") {
    NavigationStack {
        StudyScheduleRegistrationView(
            viewModel: previewStudyScheduleRegistrationViewModel()
        )
    }
    .environment(ErrorHandler())
}
#endif
