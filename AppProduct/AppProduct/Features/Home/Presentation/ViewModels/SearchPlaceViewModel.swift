//
//  SearchPlaceViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/22/26.
//

import Foundation
import MapKit
import CoreLocation

@Observable
class SearchPlaceViewModel {
    // MARK: - Property
    /// 검색어 입력값
    var searchPlace: String = ""
    /// 검색 결과 리스트
    var searchResult: Loadable<[PlaceSearchResult]> = .idle
    /// 최근 검색 장소 리스트
    var recentPlaces: [RecentPlace] = .init()
    
    /// 최근 검색어 최대 저장 개수
    private let maxRecentPlaces = 10
    
    // MARK: - Dependency
    /// 에러 핸들러
    private let errorHandler: ErrorHandler
    
    // MARK: - Init
    /// 초기화 메서드
    /// - Parameter errorHandler: 에러 핸들러
    init(errorHandler: ErrorHandler) {
        self.errorHandler = errorHandler
    }
    
    // MARK: - RecentPlace
    /// 최근 장소 불러오기
    func loadRecentPlaces() {
        guard let data = UserDefaults.standard.data(forKey: AppStorageKey.recentSearchPlaces),
              let decoded = try? JSONDecoder().decode([RecentPlace].self, from: data) else {
            recentPlaces = .init()
            return
        }
        
        recentPlaces = decoded
        #if DEBUG
        print("불러온 최근 장소: \(recentPlaces.count)개")
        #endif
    }
    
    /// 최근 장소 추가
    /// - Parameter place: 장소
    func addRecentPlace(_ place: PlaceSearchResult) async {
        let newPlace = RecentPlace(
            name: place.name,
            address: place.address,
            latitude: place.coordinate.latitude,
            longitude: place.coordinate.longitude,
            searchedAt: Date()
        )
        
        recentPlaces.removeAll(where: { $0.name == newPlace.name })
        recentPlaces.insert(newPlace, at: 0)
        
        if recentPlaces.count > maxRecentPlaces {
            recentPlaces = Array(recentPlaces.prefix(maxRecentPlaces))
        }
        
        saveRecentPlace()
    }
    
    /// 최근 장소 저장
    private func saveRecentPlace() {
        guard let encoded = try? JSONEncoder().encode(recentPlaces) else {
            #if DEBUG
            print("최근 장소 저장 실패")
            #endif
            return
        }
        
        UserDefaults.standard.set(encoded, forKey: AppStorageKey.recentSearchPlaces)
        #if DEBUG
        print("저장한 최근 장소: \(recentPlaces.count)개")
        #endif
    }
    
    /// 최근 장소 삭제
    /// - Parameter index: 삭제 장소 인덱스
    func removeRecentPlace(_ index: Int) {
        guard index < recentPlaces.count else { return }
        recentPlaces.remove(at: index)
        saveRecentPlace()
    }
    
    /// 전부 삭제
    func removeAll() {
        recentPlaces.removeAll()
        saveRecentPlace()
    }
    
    /// 검색 데이터 초기화(결과 및 쿼리)
    func clear() async {
        searchResult = .idle
        searchPlace.removeAll()
    }
    
    // MARK: - Map Search
    /// 검색 쿼리로 장소 검색 수행
    /// - Parameter query: 검색어
    public func search(query: String) async {
        guard !query.isEmpty else {
            searchResult = .loaded([])
            return
        }

        searchResult = .loading
        do {
            let results = try await performSearch(query: query)
            searchResult = .loaded(results)
        } catch is MKError {
            searchResult = .failed(.unknown(message: "검색 결과를 찾을 수 없습니다"))
        } catch {
            searchResult = .idle
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "SearchPlace", action: "search")
            )
        }
    }
    
    /// 실제 MKLocalSearch를 사용항 검색 로직
    /// - Parameter query: 검색어
    /// - Returns: 검색 결과 리스트
    private func performSearch(query: String) async throws -> [PlaceSearchResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.pointOfInterest, .address]
        request.region = setupRegion()
        
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        
        return response.mapItems.map { item in
                .init(
                    name: item.name ?? "알 수 없는 장소",
                    address: fullAddress(item),
                    coordinate: Coordinate(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude),
                    category: item.pointOfInterestCategory
                )
        }
    }
    
    /// 검색 지역 설정 (현재 위치 또는 기본 서울)
    /// - Returns: 설정된 지도 영역
    private func setupRegion() -> MKCoordinateRegion {
        if let currentLocation = LocationManager.shared.currentLocation {
            let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            return MKCoordinateRegion(center: currentLocation, span: span)
        } else {
            let seoulCenter = CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
            let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            return MKCoordinateRegion(center: seoulCenter, span: span)
        }
    }
    
    /// MKMapItem에서 주소 문자열 추출
    /// - Parameter item: 지도 아이템
    /// - Returns: 주소 문자열
    private func fullAddress(_ item: MKMapItem) -> String {
        guard let address = item.address else {
            return "주소 정보 없음"
        }
        
        return address.fullAddress
    }
    
    /// 현재 위치 정보 가져오기
    /// - Returns: 현재 위치의 장소 정보 (실패 시 nil)
    func getCurrnetLocation() async -> PlaceSearchResult? {
        do {
            let coordinate = try await LocationManager.shared.getCurrentLocation()
            let currentCoordinate = CLLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            guard let request = MKReverseGeocodingRequest(location: currentCoordinate) else {
                throw LocationError.geocodingFailed("요청을 생성할 수 없습니다.")
            }
            
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else {
                throw LocationError.geocodingFailed("위치 정보를 가져올 수 없습니다.")
            }
            
            let placeName = mapItem.name ?? "현재 위치"
            let address = fullAddress(mapItem)
            
            #if DEBUG
            print("현재 위치 - 이름: \(placeName)")
            print("현재 위치 - 주소: \(address)")
            print("좌표: \(coordinate.latitude), \(coordinate.longitude)")
            #endif
            
            return .init(name: placeName, address: address, coordinate: .init(latitude: coordinate.latitude, longitude: coordinate.longitude), category: mapItem.pointOfInterestCategory)
            
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(
                    feature: "SearchPlace",
                    action: "getCurrentLocation"
                )
            )
            return nil
        }
    }
}

