//
//  Upgradable.swift
//  SailingThroughHistory
//
//  Created by henry on 13/4/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation

protocol Upgradable {
    func installUpgrade(ship: inout ShipAPI, upgrade: Upgrade) -> (Bool, InfoMessage?)
}
