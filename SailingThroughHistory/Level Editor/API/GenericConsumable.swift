//
//  GenericConsumable.swift
//  SailingThroughHistory
//
//  Created by henry on 18/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation

protocol GenericConsumable: GenericItem {
    func consume(amount: Int) -> Int
}