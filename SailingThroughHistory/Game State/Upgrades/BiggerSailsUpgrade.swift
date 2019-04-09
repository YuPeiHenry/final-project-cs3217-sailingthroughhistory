//
//  BiggerSailsUpgrade.swift
//  SailingThroughHistory
//
//  Created by henry on 7/4/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation

class BiggerSailsUpgrade: AuxiliaryUpgrade {
    override var name: String {
        return "Cargo extension"
    }
    override var cost: Int {
        return 1000
    }

    override func getWeatherModifier() -> Double {
        return 2
    }
}