//
//  MyAttendanceHistoryTestView.swift
//  AppProduct
//
//  Created by euijjang97 on 6/11/26.
//

import SwiftUI

#if DEBUG
/// 나의 출석 현황 카드 디자인 확인용 시뮬레이터 테스트 화면
///
/// 런치 인자 `-mockAttendanceHistory` 로 실행하면 네트워크 없이
/// 출석 정책/장소/비대면 조합별 카드 레이아웃을 확인할 수 있습니다.
struct MyAttendanceHistoryTestView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                Text("나의 출석 현황 (탭하여 펼치기)")
                    .appFont(.bodyEmphasis, color: .black)
                    .padding(.leading, DefaultConstant.sectionLeadingHeader)

                ChallengerMyAttendanceStatusView(models: Self.sampleModels)

                Text("펼친 상태 예시")
                    .appFont(.bodyEmphasis, color: .black)
                    .padding(.leading, DefaultConstant.sectionLeadingHeader)
                    .padding(.top, DefaultSpacing.spacing16)

                ChallengerMyAttendanceCard(
                    model: Self.sampleModels[0],
                    isExpanded: true
                )
                .clipShape(ConcentricRectangle(
                    corners: .concentric(minimum: DefaultConstant.concentricRadius),
                    isUniform: true
                ))
                .glass()
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
        }
        .background(Color.grey100)
    }

    // MARK: - Sample Data

    /// 정책+장소 / 정책+비대면 / 정책 없음 세 조합을 모두 포함한 샘플
    static let sampleModels: [MyAttendanceItemModel] = {
        let lastWeek = Date.now.addingTimeInterval(-86400 * 7)
        let yesterday = Date.now.addingTimeInterval(-86400)

        return [
            MyAttendanceItemModel(
                week: 7,
                title: "UMC PRODUCT iOS 첫 스프린트 미팅!!",
                startTime: yesterday,
                endTime: yesterday.addingTimeInterval(2 * 3600),
                status: .present,
                category: .general,
                attendancePolicy: AttendancePolicy(
                    checkInStartAt: yesterday.addingTimeInterval(-10 * 60),
                    onTimeEndAt: yesterday.addingTimeInterval(10 * 60),
                    lateEndAt: yesterday.addingTimeInterval(2 * 3600)
                ),
                locationName: "한성대학교 상상관 6층"
            ),
            MyAttendanceItemModel(
                week: 6,
                title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
                startTime: lastWeek,
                endTime: lastWeek.addingTimeInterval(2 * 3600),
                status: .late,
                category: .general,
                attendancePolicy: AttendancePolicy(
                    checkInStartAt: lastWeek.addingTimeInterval(-10 * 60),
                    onTimeEndAt: lastWeek.addingTimeInterval(10 * 60),
                    lateEndAt: lastWeek.addingTimeInterval(2 * 3600)
                ),
                isOnline: true
            ),
            MyAttendanceItemModel(
                week: 5,
                title: "연합 네트워킹 데이",
                startTime: lastWeek.addingTimeInterval(-86400 * 7),
                endTime: lastWeek.addingTimeInterval(-86400 * 7 + 3 * 3600),
                status: .absent,
                category: .general,
                locationName: "공덕 서울창업허브"
            )
        ]
    }()
}

// MARK: - Preview

#Preview {
    MyAttendanceHistoryTestView()
}
#endif
