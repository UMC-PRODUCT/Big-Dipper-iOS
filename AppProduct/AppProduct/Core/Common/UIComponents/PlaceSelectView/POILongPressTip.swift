//
//  POILongPressTip.swift
//  AppProduct
//
//  Created by euijjang97 on 4/1/26.
//

import TipKit

/// 지도에서 POI를 길게 눌러 장소를 선택하는 방법을 안내하는 팁입니다.
///
/// 사용자가 처음 지도 선택 화면에 진입했을 때 표시되며,
/// POI를 실제로 선택하거나 직접 닫으면 다시 표시되지 않습니다.
struct POILongPressTip: Tip {
    var title: Text {
        Text("장소를 더 정확하게 선택하려면")
    }

    var message: Text? {
        Text("카페, 식당 등 지도 위 아이콘을 길게 누르면 해당 장소를 바로 선택할 수 있어요.")
    }

    var image: Image? {
        Image(systemName: "hand.tap")
    }
}
