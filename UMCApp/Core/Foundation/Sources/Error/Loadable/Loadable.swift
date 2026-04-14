//
//  Loadable.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 비동기 데이터 로딩 상태를 나타내는 열거형.
///
/// ViewModel에서 API 호출 결과를 관리할 때 사용합니다.
/// 단일 데이터 소스의 상태를 명시적으로 표현하여
/// View에서 각 상태에 맞는 UI를 렌더링할 수 있습니다.
///
/// ## Usage
///
/// **ViewModel에서 상태 관리:**
///
/// ```swift
/// @Observable
/// final class NoticeListViewModel {
///     private(set) var notices: Loadable<[Notice]> = .idle
///
///     func fetchNotices() async {
///         notices = .loading
///         do {
///             let result = try await useCase.execute()
///             notices = .loaded(result)
///         } catch let error as AppError {
///             notices = .failed(error)
///         } catch {
///             notices = .failed(.unknown(message: error.localizedDescription))
///         }
///     }
/// }
/// ```
///
/// **View에서 상태별 UI 렌더링:**
///
/// ```swift
/// struct NoticeListView: View {
///     @State private var viewModel: NoticeListViewModel
///
///     var body: some View {
///         switch viewModel.notices {
///         case .idle:
///             Color.clear.task { await viewModel.fetchNotices() }
///         case .loading:
///             ProgressView()
///         case .loaded(let notices):
///             List(notices) { NoticeRow(notice: $0) }
///         case .failed(let error):
///             ErrorView(error: error, retryAction: { Task { await viewModel.fetchNotices() } })
///         }
///     }
/// }
/// ```
///
/// ## ErrorHandler vs Loadable 선택 기준
///
/// | 기준 | ErrorHandler (Alert) | Loadable (인라인) |
/// |------|---------------------|-------------------|
/// | **사용자 액션** | 즉각적인 액션 필요 | 화면 내에서 해결 가능 |
/// | **작업 흐름** | 중단해야 함 | 유지 가능 |
/// | **에러 예시** | 세션 만료, 네트워크 오류 | 범위 밖, 이미 제출됨 |
///
/// ## 에러 타입별 catch 분기 패턴
///
/// ```swift
/// do {
///     let result = try await useCase.execute()
///     state = .loaded(result)
///
/// } catch let error as DomainError {
///     // 도메인 에러 → Loadable (인라인)
///     state = .failed(.domain(error))
///
/// } catch {
///     // 기타 에러 → ErrorHandler (Alert) + 상태 복구
///     state = .loaded(initialData)  // 또는 .idle
///     errorHandler.handle(error, context: ...)
/// }
/// ```
///
/// - SeeAlso: ``AppError``, ``ErrorHandler``, ``DomainError``
public enum Loadable<T: Equatable>: Equatable {

    // MARK: - Cases

    /// 초기 상태.
    ///
    /// 아직 데이터 로딩이 시작되지 않은 상태입니다.
    /// View가 나타날 때 `.onAppear`에서 로딩을 시작하는 트리거로 사용합니다.
    case idle

    /// 로딩 중 상태.
    ///
    /// 데이터를 요청 중이며 응답을 기다리는 상태입니다.
    /// `ProgressView`나 스켈레톤 UI를 표시하세요.
    case loading

    /// 로딩 성공 상태.
    ///
    /// 데이터 로딩이 성공적으로 완료된 상태입니다.
    ///
    /// - Parameter value: 로드된 데이터.
    case loaded(T)

    /// 로딩 실패 상태.
    ///
    /// 데이터 로딩 중 에러가 발생한 상태입니다.
    /// 에러 메시지와 재시도 버튼을 표시하세요.
    ///
    /// - Parameter error: 발생한 에러.
    case failed(AppError)

    // MARK: - Computed Property

    /// 로드된 값.
    ///
    /// `.loaded` 상태일 때만 값을 반환하고, 그 외에는 `nil`을 반환합니다.
    ///
    /// ```swift
    /// if let notices = viewModel.notices.value {
    ///     // notices 사용
    /// }
    /// ```
    public var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }

    /// 발생한 에러.
    ///
    /// `.failed` 상태일 때만 에러를 반환하고, 그 외에는 `nil`을 반환합니다.
    ///
    /// ```swift
    /// if let error = viewModel.notices.error {
    ///     print(error.errorDescription)
    /// }
    /// ```
    public var error: AppError? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }

    /// 로딩 중 여부.
    ///
    /// `ProgressView` 표시 조건으로 사용합니다.
    ///
    /// ```swift
    /// if viewModel.notices.isLoading {
    ///     ProgressView()
    /// }
    /// ```
    public var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }

    /// 로드 완료 여부.
    ///
    /// 성공(`.loaded`) 또는 실패(`.failed`) 상태인지 확인합니다.
    /// 최초 로딩이 완료되었는지 판단할 때 사용합니다.
    public var isComplete: Bool {
        switch self {
        case .loaded, .failed:
            return true
        default:
            return false
        }
    }

    /// 초기 상태 여부.
    ///
    /// 아직 로딩이 시작되지 않았는지 확인합니다.
    /// `.task`에서 최초 로딩 트리거 조건으로 사용합니다.
    ///
    /// ```swift
    /// .task {
    ///     if viewModel.notices.isIdle {
    ///        await viewModel.fetchNotices()
    ///     }
    /// }
    /// ```
    public var isIdle: Bool {
        if case .idle = self {
            return true
        }
        return false
    }

    // MARK: - Mapping

    /// 로드된 값을 다른 타입으로 변환합니다.
    ///
    /// 함수형 프로그래밍의 `map` 패턴을 적용하여
    /// 상태를 유지하면서 내부 값만 변환합니다.
    ///
    /// ```swift
    /// let noticeCount: Loadable<Int> = viewModel.notices.map { $0.count }
    /// ```
    ///
    /// - Parameter transform: 값을 변환하는 클로저.
    /// - Returns: 변환된 값을 담은 새로운 `Loadable`.
    ///
    /// - Note: `.idle`, `.loading`, `.failed` 상태는 그대로 유지됩니다.
    public func map<U: Equatable>(_ transform: (T) -> U) -> Loadable<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .failed(let error):
            return .failed(error)
        }
    }
}
