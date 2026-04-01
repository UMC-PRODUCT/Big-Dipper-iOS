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
        Text("장소 선택 팁")
    }

    var message: Text? {
        Text("POI를 길게 눌러 장소를 선택할 수 있어요")
    }

    var image: Image? {
        Image(systemName: "hand.tap")
    }
}
