//
//  EventParameters.swift
//  SailingThroughHistory
//
//  Created by ysq on 3/19/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation

struct EventParameter: Codable {

}

extension EventParameter: Equatable {
    static func == (lhs: EventParameter, rhs: EventParameter) -> Bool {
        return true
    }
}
