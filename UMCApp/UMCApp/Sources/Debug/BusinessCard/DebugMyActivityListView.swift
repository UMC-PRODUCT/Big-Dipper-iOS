//
//  DebugMyActivityListView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreDI
import CoreDomain
import Observation
import SwiftUI
import UMCFoundation

/// 마이페이지 「나의 활동・프로젝트」 행의 임시 목록 화면.
///
/// **탭 이동이 없다.** 활동 이력에 대응하는 상세 화면도, 목적지 case 도, 서버 개념도 없기
/// 때문이다. "프로젝트"에 해당하는 엔티티는 도메인·DTO 어디에도 존재하지 않는다 — 목록에
/// 프로젝트를 넣으려면 서버 API 신설이 선행돼야 한다.
///
/// 목록 소스는 `GET /api/v1/member/me` 의 `challengerRecords` 하나뿐이고, 여기에는 기간·
/// 시작일·종료일·설명·썸네일이 없다. 그래서 행에 그릴 수 있는 건 기수·파트·학교·지부·상태뿐이다.
///
/// 예전에는 이 화면이 **카운트 정의가 두 갈래라는 사실**을 보여 주는 용도였다. 지금은
/// 명함 카운트도 마이페이지 목록도 `Profile.activityLogs()` 하나를 보므로 (#1222)
/// 그 숫자와 원본 기록을 나란히 놓고 파생이 맞는지 확인한다.
struct DebugMyActivityListView: View {

    // MARK: - Property

    @State private var viewModel: DebugMyActivityListViewModel

    // MARK: - Init

    init(container: DIContainer) {
        _viewModel = State(initialValue: DebugMyActivityListViewModel(container: container))
    }

    // MARK: - Body

    var body: some View {
        List {
            sourceSection
            countSection
            resultSection
        }
        .navigationTitle("나의 활동・프로젝트 (검증)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
    }

    // MARK: - Section

    private var sourceSection: some View {
        Section("데이터 출처") {
            LabeledContent("소스") {
                Text("GET /api/v1/member/me\n→ Profile.challengerRecords")
                    .font(.caption)
                    .monospaced()
                    .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("탭 이동 없음", systemImage: "xmark.circle.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.red)

                Text("""
                활동 이력 상세 화면도, 목적지 case 도 없다. 「프로젝트」에 대응하는 서버 개념 \
                자체가 코드베이스에 존재하지 않는다(도메인 모델·DTO·엔드포인트 전부 0건). \
                그래서 행을 눌러도 갈 곳이 없다.
                """)
                .font(.caption)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("메타 빈곤", systemImage: "tray.fill")
                    .font(.footnote.bold())
                    .foregroundStyle(.secondary)

                Text("""
                기간·시작일·종료일·프로젝트명·설명·썸네일 필드가 도메인과 DTO 양쪽에 없다. \
                아래 행이 표시할 수 있는 전부다.
                """)
                .font(.caption)
            }
        }
    }

    private var countSection: some View {
        Section("활동 카운트") {
            LabeledContent("activityLogs 항목 수") {
                Text("\(viewModel.activityCount)건")
                    .font(.body.bold())
            }

            Text("""
            명함 `activityCount` 와 마이페이지 활동 목록이 같은 `Profile.activityLogs()` \
            를 센다 (#1222). 아래 원본 기록보다 적을 수 있다 — 같은 기수의 운영진 역할은 \
            한 줄로 병합되고, 파싱 안 되는 파트 코드는 빠진다.
            """)
            .font(.caption)
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch viewModel.records {
        case .idle, .loading:
            Section {
                ProgressView().frame(maxWidth: .infinity)
            }

        case .loaded(let records) where records.isEmpty:
            Section("결과") {
                Text("챌린저 기수 이력이 없다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

        case .loaded(let records):
            Section("기수 이력 \(records.count)건 (admin 포함 전체)") {
                ForEach(records, id: \.challengerId) { record in
                    row(record)
                }
            }

        case .failed(let error):
            Section("결과") {
                Text("조회 실패: \(error.errorDescription ?? error.localizedDescription)")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - View Component

    private func row(_ record: ProfileChallengerRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(record.gisu)기")
                    .font(.body.bold())

                Text(partLabel(record.part))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: .capsule)

                Spacer(minLength: 4)

                Text(statusLabel(record.status))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text([record.schoolName, record.chapterName].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !record.challengerPoints.isEmpty {
                Text("포인트 이력 \(record.challengerPoints.count)건 · 합계 \(pointSum(record))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Function

    /// 서버가 보낸 파트 코드가 앱이 아는 값인지 그대로 드러낸다 — 카운트 차이의 원인이다.
    private func partLabel(_ apiValue: String) -> String {
        guard let part = UMCPartType(apiValue: apiValue) else {
            return "\(apiValue) (미지)"
        }
        return part.name
    }

    private func statusLabel(_ status: MemberStatus) -> String {
        switch status {
        case .active:    return "활동 중"
        case .inactive:  return "비활성"
        case .withdrawn: return "탈퇴"
        }
    }

    private func pointSum(_ record: ProfileChallengerRecord) -> String {
        let sum = record.challengerPoints.reduce(0) { $0 + $1.point }
        return String(format: "%.1f", sum)
    }
}

/// ``DebugMyActivityListView`` 상태.
@Observable
final class DebugMyActivityListViewModel {

    // MARK: - Property

    var records: Loadable<[ProfileChallengerRecord]> = .idle

    /// 마이페이지 활동 목록·명함 `activityCount` 가 함께 쓰는 정본 파생 결과의 항목 수.
    private(set) var activityCount = 0

    private let memberProfileRepository: MemberProfileRepositoryProtocol

    // MARK: - Init

    init(container: DIContainer) {
        self.memberProfileRepository = container.resolve(MemberProfileRepositoryProtocol.self)
    }

    // MARK: - Function

    func load() async {
        records = .loading
        do {
            let profile = try await memberProfileRepository.fetchMyProfile(forceRefresh: false)
            let all = profile.challengerRecords
            records = .loaded(all)
            activityCount = profile.activityLogs().count
        } catch let error as AppError {
            records = .failed(error)
        } catch {
            records = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
#endif
