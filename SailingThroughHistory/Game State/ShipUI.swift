//
//  ShipUI.swift
//  SailingThroughHistory
//
//  Created by henry on 19/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import UIKit

class ShipUI: GameObject {

    private let shipImagePath = "ship.png"
    private let shipWidth: Double = 50

    init(ship: Ship) {
        guard let frame = Rect(originX: 0, originY: 0, height: shipWidth, width: shipWidth) else {
            fatalError("shipWidth is invalid.")
        }
        super.init(image: shipImagePath, frame: frame)
        ship.location.subscribe(with: moveShip)
    }

    required init(from decoder: Decoder) throws {
        try super.init(from: decoder)
    }

    private func moveShip(to location: Location) {
        let start = location.start
        let end = location.end
        let fraction = CGFloat(location.fractionToEnd)
        let newX: Double = Double(start.frame.midX * fraction + end.frame.midX * (1 - fraction)) - shipWidth / 2
        let newY: Double = Double(start.frame.midY * fraction + end.frame.midY * (1 - fraction)) - shipWidth / 2
        guard let frame = Rect(originX: newX, originY: newY, height: shipWidth, width: shipWidth) else {
            fatalError("New frame is invalid")
        }

        self.frame = frame
    }

}
