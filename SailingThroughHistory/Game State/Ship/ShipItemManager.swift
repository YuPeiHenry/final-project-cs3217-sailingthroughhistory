//
//  ShipItemManager.swift
//  SailingThroughHistory
//
//  Created by henry on 13/4/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation

class ShipItemManager: ItemStorage {
    func getPurchasableItemParameters(ship: ShipAPI) -> [ItemParameter] {
        guard let port = ship.node as? Port, ship.isDocked else {
            return []
        }
        return port.itemParametersSoldByPort
    }

    func getMaxPurchaseAmount(ship: ShipAPI, itemParameter: ItemParameter) -> Int {
        guard let map = ship.map else {
            fatalError("Ship does not reside on any map.")
        }
        guard let port = map.nodeIDPair[ship.nodeId] as? Port, ship.isDocked,
            let unitValue = port.getBuyValue(of: itemParameter) else {
                return 0
        }
        return min(ship.owner?.money.value ?? 0 / unitValue, getRemainingCapacity(ship: ship) / itemParameter.unitWeight)
    }

    func buyItem(ship: ShipAPI, itemParameter: ItemParameter, quantity: Int) throws {
        guard let port = ship.node as? Port, ship.isDocked else {
            throw TradeItemError.notDocked
        }
        let item = itemParameter.createItem(quantity: quantity)
        guard let price = item.getBuyValue(at: port) else {
            throw TradeItemError.itemNotAvailable
        }
        let difference = (ship.owner?.money.value ?? 0) - price
        guard difference >= 0 else {
            throw TradeItemError.insufficientFunds(shortOf: difference)
        }
        try addItem(ship: ship, item: item)
        ship.owner?.updateMoney(by: -price)
        ship.updateCargoWeight(items: ship.items.value)
    }

    func sellItem(ship: ShipAPI, item: GenericItem) throws {
        guard let port = ship.node as? Port, ship.isDocked else {
            throw TradeItemError.notDocked
        }
        guard let index = ship.items.value.firstIndex(where: {$0 == item}) else {
            throw TradeItemError.itemNotAvailable
        }
        guard let profit = ship.items.value[index].sell(at: port) else {
            throw TradeItemError.itemNotAvailable
        }
        ship.owner?.updateMoney(by: profit)
        ship.items.value.remove(at: index)
        ship.items.value = ship.items.value
        ship.updateCargoWeight(items: ship.items.value)
    }

    func sell(ship: ShipAPI, itemParameter: ItemParameter, quantity: Int) throws {
        guard let map = ship.map, let port = map.nodeIDPair[ship.nodeId] as? Port else {
            throw TradeItemError.notDocked
        }
        guard let value = port.getSellValue(of: itemParameter) else {
            throw TradeItemError.itemNotAvailable
        }
        let deficit = removeItem(ship: ship, by: itemParameter, with: quantity)
        ship.owner?.updateMoney(by: (quantity - deficit) * value)
        if deficit > 0 {
            throw TradeItemError.insufficientItems(shortOf: deficit, sold: quantity - deficit)
        }
    }

    func removeItem(ship: ShipAPI, by itemParameter: ItemParameter, with quantity: Int) -> Int {
        guard let index = ship.items.value.firstIndex(where: { $0.itemParameter == itemParameter }) else {
            return quantity
        }
        let deficit = ship.items.value[index].remove(amount: quantity)
        if ship.items.value[index].quantity == 0 {
            ship.items.value.remove(at: index)
            ship.items.value = ship.items.value
        }
        guard deficit <= 0 else {
            return removeItem(ship: ship, by: itemParameter, with: deficit)
        }
        return 0
    }

    private func getRemainingCapacity(ship: ShipAPI) -> Int {
        return ship.weightCapacity - ship.currentCargoWeight
    }

    private func addItem(ship: ShipAPI, item: GenericItem) throws {
        let difference = getRemainingCapacity(ship: ship) - (item.weight ?? 0)
        guard difference >= 0 else {
            throw TradeItemError.insufficientCapacity(shortOf: difference)
        }
        guard let sameType = ship.items.value.first(where: { $0.itemParameter == item.itemParameter }) else {
            ship.items.value.append(item)
            return
        }
        _ = sameType.combine(with: item)
        return
    }
}
