//
//  Path.swift
//  SailingThroughHistory
//
//  Created by Jason Chong on 18/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import UIKit

struct Path: Hashable, Codable {
    let fromObject: GameObject
    let toObject: GameObject

    init(from: GameObject, to: GameObject) {
        fromObject = from
        toObject = to
    }
}
