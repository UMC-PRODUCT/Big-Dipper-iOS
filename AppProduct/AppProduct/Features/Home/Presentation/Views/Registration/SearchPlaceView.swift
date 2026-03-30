//
//  SearchMapView.swift
//  AppProduct
//
//  Created by euijjang97 on 1/22/26.
//

import CoreLocation
import MapKit
import SwiftUI

/// 일정 등록 화면에서 장소를 검색하거나 지도에서 선택하도록 돕는 시트입니다.
///
/// 검색 탭에서는 키워드 검색과 최근 검색 기록을 제공하고,
/// 지도 탭에서는 핀을 이동한 뒤 확인 버튼으로 위치를 확정합니다.
struct SearchMapView: View {
    // MARK: - Property

    /// 시트 닫힘을 제어합니다.
    @Environment(\.dismiss) var dismiss
    /// 검색어 입력, 검색 결과, 최근 검색 기록을 관리합니다.
    @State var viewModel: SearchPlaceViewModel
    /// 검색창 포커스 상태를 제어합니다.
    @FocusState var isFocused: Bool
    /// 검색 UI와 지도 UI 사이의 현재 탭 상태입니다.
    @State private var searchMode: SearchMode = .search
    /// 지도 선택 임시 상태를 유지합니다.
    @State private var mapPickerState: InlineMapPickerState = .init()

    /// 장소가 선택되었을 때 호출되는 클로저
    var placeSelected: (PlaceSearchInfo) -> Void

    /// 장소 선택 시트의 상단 모드 전환 값입니다.
    enum SearchMode: String, CaseIterable, Identifiable {
        case search = "검색"
        case map = "지도"

        var id: String { rawValue }
    }

    // MARK: - Header

    /// 검색 섹션 헤더의 제목 종류입니다.
    enum MapHeaderType: String {
        case recent = "최근 검색"
        case search = "검색 위치"
    }

    // MARK: - Constant

    /// 검색 화면에서 사용하는 문자열 및 시스템 아이콘 상수입니다.
    enum Constants {
        static let placeholder: String = "Apple 지도"
        static let magnifyingglass: String = "magnifyingglass"
        static let currentLocation: String = "location.fill"
        static let subTitle: String = "핀을 눌러 위치를 선택하세요"
        static let confirmButtonTitle: String = "이 위치로 선택"
        static let confirmingTitle: String = "확인 중"
        static let confirmButtonIcon: String = "checkmark.circle.fill"
    }

    // MARK: - Init

    /// 장소 선택 시트를 초기 상태와 함께 생성합니다.
    ///
    /// - Parameters:
    ///   - initialPlace: 기존에 선택된 장소입니다. 지도 탭 진입 시 해당 좌표를 초기 핀으로 사용합니다.
    ///   - errorHandler: 검색 및 현재 위치 조회 실패를 처리할 `ErrorHandler`입니다.
    ///   - placeSelected: 최종 선택된 장소를 상위 폼에 반영하는 클로저입니다.
    init(
        initialPlace: PlaceSearchInfo? = nil,
        errorHandler: ErrorHandler,
        placeSelected: @escaping (PlaceSearchInfo) -> Void
    ) {
        self._viewModel = .init(wrappedValue: .init(errorHandler: errorHandler))
        self._mapPickerState = .init(
            wrappedValue: .init(initialPlace: initialPlace)
        )
        self.placeSelected = placeSelected
    }

    // MARK: - Body

    /// 검색 시트의 기본 내비게이션과 툴바를 조합한 본문입니다.
    var body: some View {
        NavigationStack {
            navigationContent
        }
    }

    /// 공통 내비게이션 구성을 적용한 뒤, 지도 모드에서만 서브타이틀을 추가합니다.
    @ViewBuilder
    private var navigationContent: some View {
        if searchMode == .map {
            content
                .navigation(naviTitle: .placeSearch, displayMode: .inline)
                .navigationSubtitle(Constants.subTitle)
                .toolbar(content: {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        modeToggleButton
                        currnetLocation
                    }
                    
                    ToolbarItem(placement: .bottomBar) {
                        mapConfirmButton
                    }
                })
                .task {
                    viewModel.loadRecentPlaces()
                }
                .backgroundExtensionEffect()
        } else {
            content
                .navigation(naviTitle: .placeSearch, displayMode: .inline)
                .toolbar(content: {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        modeToggleButton
                        currnetLocation
                    }
                })
                .task {
                    viewModel.loadRecentPlaces()
                }
        }
    }

    /// 현재 모드에 따라 검색 폼 또는 지도 선택 뷰를 렌더링합니다.
    @ViewBuilder
    private var content: some View {
        switch searchMode {
        case .search:
            Form {
                recentSearches
                mapSearchResult
            }
            .searchable(
                text: $viewModel.searchPlace,
                placement: .toolbarPrincipal,
                prompt: Constants.placeholder
            )
            .searchFocused($isFocused)
            .onSubmit(of: .search, {
                searchAction(viewModel.searchPlace)
            })
            .onChange(of: viewModel.searchPlace, { _, new in
                searchAction(new)
            })
            .searchPresentationToolbarBehavior(.avoidHidingContent)

        case .map:
            InlineMapPlacePicker(state: mapPickerState)
            .umcDefaultBackground()
        }
    }

    /// 현재 위치 버튼 뷰
    private var currnetLocation: some View {
        Button(action: {
            Task {
                if searchMode == .map {
                    await mapPickerState.moveToCurrentLocation()
                    return
                }

                if let currentPlace = await viewModel.getCurrnetLocation() {
                    let placeInfo = PlaceSearchInfo(
                        name: currentPlace.name,
                        address: currentPlace.address ?? "도로명 주소 없음",
                        coordinate: currentPlace.coordinate
                    )
                    placeSelected(placeInfo)
                    dismiss()
                }
            }
        }, label: {
            Image(systemName: Constants.currentLocation)
                .renderingMode(.template)
                .foregroundStyle(.indigo500)
        })
    }

    private var modeToggleButton: some View {
        Button(action: {
            withAnimation {
                searchMode = searchMode == .search ? .map : .search
            }
        }) {
            Image(systemName: searchMode == .search ? "map" : "magnifyingglass")
                .renderingMode(.template)
                .foregroundStyle(.indigo500)
        }
        .accessibilityLabel(searchMode == .search ? "지도로 보기" : "검색으로 보기")
    }

    /// 지도 모드에서 하단 toolbar에 노출되는 위치 확정 버튼입니다.
    private var mapConfirmButton: some View {
        let canConfirmSelection = mapPickerState.selectedPlace != nil && !mapPickerState.isResolvingPlace

        return Button(action: {
            guard let selectedPlace = mapPickerState.selectedPlace else {
                return
            }

            placeSelected(selectedPlace)
            dismiss()
        }, label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                if mapPickerState.isResolvingPlace {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.indigo700)
                } else {
                    Image(systemName: Constants.confirmButtonIcon)
                        .font(.body.weight(.semibold))
                }

                Text(
                    mapPickerState.isResolvingPlace
                    ? Constants.confirmingTitle
                    : Constants.confirmButtonTitle
                )
                .font(.headline.weight(.semibold))
                .lineLimit(1)
            }
            .foregroundStyle(canConfirmSelection ? .indigo700 : .grey400)
            .padding(.horizontal, DefaultSpacing.spacing16)
            .padding(.vertical, DefaultSpacing.spacing12)
            .frame(minWidth: 180)
        })
        .buttonStyle(.plain)
        .disabled(!canConfirmSelection)
    }

    /// 검색어가 비어 있을 때 최근 검색 기록 섹션을 노출합니다.
    @ViewBuilder
    private var recentSearches: some View {
        if viewModel.searchPlace.isEmpty {
            Section(content: {
                if !viewModel.recentPlaces.isEmpty {
                    List {
                        ForEach(viewModel.recentPlaces, id: \.id) { place in
                            recentBtn(place)
                        }
                        .onDelete(perform: rencetDataDelete)
                    }
                } else {
                    ContentUnavailableView(
                        "최근 검색 기록이 없습니다",
                        systemImage: "magnifyingglass",
                        description: Text("관심 있는 장소를 검색하여 찾아보세요.")
                    )
                }
            }, header: {
                generateHeader(
                    .recent,
                    isShowBtn: !viewModel.recentPlaces.isEmpty
                )
            })
        }
    }

    /// 검색 결과 상태에 따라 검색 위치 섹션을 노출합니다.
    @ViewBuilder
    private var mapSearchResult: some View {
        switch viewModel.searchResult {
        case .idle:
            EmptyView()

        case .loading:
            Section(header: generateHeader(.search)) {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
            }

        case .loaded(let results):
            if !results.isEmpty {
                Section(header: generateHeader(.search)) {
                    List(results, rowContent: { place in
                        SearchContent(place: place) {
                            Task {
                                await viewModel.addRecentPlace(place)
                                await viewModel.clear()
                                placeSelected(.init(
                                    name: place.name,
                                    address: place.address ?? "도로명 주소 없음",
                                    coordinate: place.coordinate
                                ))
                                dismiss()
                            }
                        }
                        .equatable()
                    })
                }
            } else {
                Section(header: generateHeader(.search)) {
                    ContentUnavailableView(
                        "검색 결과가 없습니다",
                        systemImage: "magnifyingglass",
                        description: Text("다른 검색어로 다시 시도해보세요.")
                    )
                }
            }

        case .failed(let error):
            Section(header: generateHeader(.search)) {
                ContentUnavailableView(
                    error.errorDescription ?? "검색에 실패했습니다",
                    systemImage: "exclamationmark.triangle",
                    description: Text("다른 검색어로 다시 시도해보세요.")
                )
            }
        }
    }
}

// MARK: - Helper

extension SearchMapView {
    /// 최근 검색 셀에 사용하는 돋보기 아이콘입니다.
    private var labelIcon: some View {
        Image(systemName: Constants.magnifyingglass)
            .renderingMode(.template)
            .foregroundStyle(.grey700)
    }

    /// 최근 검색어를 검색창에 다시 채워 넣는 버튼을 생성합니다.
    ///
    /// - Parameter place: 다시 검색할 최근 장소 정보입니다.
    private func recentBtn(_ place: RecentPlace) -> some View {
        Button(action: {
            viewModel.searchPlace = place.name
            isFocused.toggle()
        }, label: {
            Label(title: { labelTitle(place.name) }, icon: {
                labelIcon
            })
            .labelIconToTitleSpacing(DefaultSpacing.spacing8)
        })
    }

    /// 검색어 변경 또는 제출 시 장소 검색을 시작합니다.
    ///
    /// - Parameter query: MapKit 검색에 전달할 자연어 검색어입니다.
    private func searchAction(_ query: String) {
        Task {
            await viewModel.search(query: query)
        }
    }

    /// 최근 검색 셀의 제목 텍스트 스타일을 통일합니다.
    private func labelTitle(_ title: String) -> some View {
        Text(title)
            .appFont(.body, color: .black)
    }

    /// 최근 검색과 검색 결과 섹션에서 공통으로 사용하는 헤더를 생성합니다.
    ///
    /// - Parameters:
    ///   - type: 헤더 제목에 사용할 섹션 종류입니다.
    ///   - isShowBtn: 최근 검색 전체 삭제 버튼 노출 여부입니다.
    private func generateHeader(
        _ type: MapHeaderType,
        isShowBtn: Bool = false
    ) -> some View {
        HStack {
            Text(type.rawValue)
                .font(.body)
                .foregroundStyle(.gray)
                .fontWeight(.semibold)

            Spacer()

            if isShowBtn {
                Button(role: .destructive, action: {
                    viewModel.removeAll()
                }) {
                    Text("전체 삭제")
                        .appFont(.footnote, color: .red500)
                }
            }
        }
    }

    /// 최근 검색 기록 목록에서 선택한 인덱스를 제거합니다.
    ///
    /// - Parameter index: 삭제할 최근 검색 항목의 인덱스 집합입니다.
    private func rencetDataDelete(index: IndexSet) {
        viewModel.recentPlaces.remove(atOffsets: index)
    }
}

#Preview {
    @Previewable @State var show: Bool = false

    VStack {
        Button(action: {
            show.toggle()
        }, label: {
            Text("111")
        })
    }
    .sheet(isPresented: $show, content: {
        SearchMapView(errorHandler: .init()) { place in
            print(place)
        }
        .presentationDragIndicator(.visible)
    })
}
