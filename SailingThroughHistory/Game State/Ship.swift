//
//  Ship.swift
//  SailingThroughHistory
//
//  Created by henry on 17/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import Foundation
import UIKit

class Ship: Codable {
    var name: String {
        return owner?.name ?? "NPC Ship"
    }

    private let suppliesConsumed: [GenericItem]
    private var isChasedByPirates = false
    private var turnsToBeingCaught = 0

    var nodeId: Int {
        get {
            return nodeIdVariable.value
        }
        set {
            nodeIdVariable.value = newValue
        }
    }
    var currentCargoWeight: Int {
        return currentCargoWeightVariable.value
    }
    var weightCapacity: Int {
        return weightCapacityVariable.value
    }
    private let nodeIdVariable: GameVariable<Int>
    private weak var owner: GenericPlayer?
    private var items = GameVariable<[GenericItem]>(value: [])
    private var currentCargoWeightVariable = GameVariable<Int>(value: 0)
    private var weightCapacityVariable = GameVariable<Int>(value: 100)
    private(set) var isDocked = false

    private var shipChassis: ShipChassis?
    private var auxiliaryUpgrade: AuxiliaryUpgrade?
    private var shipUI: ShipUI?

    weak var map: Map? {
        didSet {
            self.nodeId = self.nodeIdVariable.value
        }
    }

    init(node: Node, suppliesConsumed: [GenericItem]) {
        self.nodeIdVariable = GameVariable(value: node.identifier)
        self.suppliesConsumed = suppliesConsumed

        subscribeToItems(with: updateCargoWeight)
        shipUI = ShipUI(ship: self)
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        nodeIdVariable = GameVariable(value: try values.decode(Int.self, forKey: .nodeID))
        suppliesConsumed = try values.decode([Item].self, forKey: .items)
        items.value = try values.decode([Item].self, forKey: .items)
        shipChassis = try values.decode(ShipChassis.self, forKey: .shipChassis)
        auxiliaryUpgrade = try values.decode(AuxiliaryUpgrade.self, forKey: .auxiliaryUpgrade)
        shipUI = ShipUI(ship: self)
    }

    func encode(to encoder: Encoder) throws {
        guard let suppliesConsumed = suppliesConsumed as? [Item],
            let shipItems = items.value as? [Item] else {
                return
        }
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(nodeId, forKey: .nodeID)
        try container.encode(suppliesConsumed, forKey: .suppliesConsumed)
        try container.encode(shipItems, forKey: .items)
        try container.encode(shipChassis, forKey: .shipChassis)
        try container.encode(auxiliaryUpgrade, forKey: .auxiliaryUpgrade)
    }

    private enum CodingKeys: String, CodingKey {
        case nodeID
        case suppliesConsumed
        case items
        case shipChassis
        case auxiliaryUpgrade
    }

    func setLocation(map: Map) {
        /*guard let node = map.nodeIDPair[nodeId] else {
            return
        }
        let location = Location(start: nodeId, end: nodeId, fractionToEnd: 0, isDocked: node is Port)
        self.location.value = location*/
    }

    func installUpgrade(upgrade: Upgrade) {
        guard let owner = owner else {
            return
        }
        if owner.money.value < upgrade.cost {
            showMessage(titled: "Insufficient Money!", withMsg: "You do not have sufficient funds to buy \(upgrade.name)!")
        }
        if shipChassis == nil, let shipUpgrade = upgrade as? ShipChassis {
            owner.updateMoney(by: -upgrade.cost)
            shipChassis = shipUpgrade
            showMessage(titled: "Ship upgrade purchased!", withMsg: "You have purchased \(upgrade.name)!")
            weightCapacityVariable.value = shipUpgrade.getNewCargoCapacity(baseCapacity: weightCapacity)
            return
        }
        if auxiliaryUpgrade == nil, let auxiliary = upgrade as? AuxiliaryUpgrade {
            owner.updateMoney(by: -upgrade.cost)
            auxiliaryUpgrade = auxiliary
            showMessage(titled: "Ship upgrade purchased!", withMsg: "You have purchased \(upgrade.name)!")
            return
        }
        if upgrade is ShipChassis {
            showMessage(titled: "\(owner.name): Upgrade of similar type already purchased!", withMsg: "You already have an upgrade of type \"Ship Upgrade\"!")
        } else if upgrade is AuxiliaryUpgrade {
            showMessage(titled: "\(owner.name): Upgrade of similar type already purchased!", withMsg: "You already have an upgrade of type \"Auxiliary Upgrade\"!")
        }
    }

    func setOwner(owner: GenericPlayer) {
        self.owner = owner
        for item in items.value {
            guard let itemParameter = owner.getItemParameter(itemType: item.itemType) else {
                continue
            }
            item.setItemParameter(itemParameter)
        }
    }

    func setMap(map: Map) {
        guard let shipUI = shipUI else {
            return
        }
        self.map = map
        map.addGameObject(gameObject: shipUI)
    }

    // Movement

    func startTurn() {
        if isChasedByPirates && turnsToBeingCaught <= 0 {
            // TODO: Pirate event
            showMessage(titled: "Pirates!", withMsg: "You have been caught by pirates!. You lost all your cargo")

            isChasedByPirates = false
            turnsToBeingCaught = 0
        }
    }

    func getNodesInRange(roll: Int, speedMultiplier: Double, map: Map) -> [Node] {
        guard let startNode = map.nodeIDPair[nodeId] else {
            fatalError("Ship has invalid node id.")
        }

        let movement = computeMovement(roll: roll, speedMultiplier: speedMultiplier)
        let nodesFromStart = startNode.getNodesInRange(ship: self, range: movement, map: map) 
        return nodesFromStart
    }

    func move(node: Node) {
        self.nodeId = node.identifier
        let nodeFrame = getCurrentNode().frame
        guard let currentFrame = shipUI?.frame.value else {
            return
        }
        shipUI?.frame.value = currentFrame.movedTo(originX: nodeFrame.originX,
                                                   originY: nodeFrame.originY)
    }

    func canDock() -> Bool {
        guard let map = map else {
            fatalError("Ship does not reside on any map.")
        }
        return map.nodeIDPair[nodeId] as? Port != nil
    }

    func dock() -> Port? {
        guard let map = map else {
            fatalError("Ship does not reside on any map.")
        }
        guard canDock() else {
            showMessage(titled: "Unable to Dock!", withMsg: "Ship is not located at a port for docking.")
            return nil
        }
        guard let port = map.nodeIDPair[nodeId] as? Port else {
            return nil
        }

        isDocked = true
        isChasedByPirates = false
        turnsToBeingCaught = 0
        return port
    }

    // Items

    func getPurchasableItemTypes() -> [ItemType] {
        guard let port = getCurrentNode() as? Port, isDocked else {
            return []
        }
        return port.itemParametersSoldByPort
    }

    func getMaxPurchaseAmount(itemParameter: ItemParameter) -> Int {
        guard let map = map else {
            fatalError("Ship does not reside on any map.")
        }
        guard let port = map.nodeIDPair[nodeId] as? Port, isDocked,
            let unitValue = port.getBuyValue(of: itemParameter) else {
            return 0
        }
        return min(owner?.money.value ?? 0 / unitValue, getRemainingCapacity() / itemParameter.unitWeight)
    }

    func buyItem(itemType: ItemType, quantity: Int) throws {
        // TODO: auto-dock
        guard let port = getCurrentNode() as? Port, isDocked else {
            showMessage(titled: "Not docked!", withMsg: "Unable to buy item as ship is not docked.")
            throw BuyItemError.notDocked
        }
        guard let itemParameter = owner?.getItemParameter(itemType: itemType) else {
            showMessage(titled: "Game Error!", withMsg: "Error getting item type!")
            throw BuyItemError.unknownItem
        }
        let item = itemParameter.createItem(quantity: quantity)
        guard let price = item.getBuyValue(at: port) else {
            showMessage(titled: "Not available!", withMsg: "Item is not available for purchase at current port!")
            throw BuyItemError.itemNotAvailable
        }
        let difference = (owner?.money.value ?? 0) - price
        guard difference >= 0 else {
            throw BuyItemError.insufficientFunds(shortOf: difference)
        }
        owner?.updateMoney(by: -price)
        try addItem(item: item)
    }

    func sellItem(item: GenericItem) throws {
        guard let port = getCurrentNode() as? Port, isDocked else {
            showMessage(titled: "Not docked!", withMsg: "Unable to sell item as ship is not docked.")
            throw BuyItemError.notDocked
        }
        guard let itemType = item.itemParameter else {
            showMessage(titled: "Game Error", withMsg: "Unable to get item type!")
            throw BuyItemError.unknownItem
        }
        guard let index = items.value.firstIndex(where: {$0 == item}) else {
            showMessage(titled: "Not available!", withMsg: "You do not possess the item!")
            throw BuyItemError.itemNotAvailable
        }
        guard let profit = items.value[index].sell(at: port) else {
            showMessage(titled: "Not available!", withMsg: "Item cannot be sold at current port!")
            throw BuyItemError.itemNotAvailable
        }
        showMessage(titled: "Item sold!", withMsg: "You have sold \(item.quantity) of \(itemType.displayName)")
        owner?.updateMoney(by: profit)
        items.value.remove(at: index)
        items.value = items.value
    }

    func sell(itemType: ItemType, quantity: Int) throws {
        guard let map = map, let port = map.nodeIDPair[nodeId] as? Port else {
            throw BuyItemError.notDocked
        }
        guard let value = port.getSellValue(of: itemType) else {
            throw BuyItemError.itemNotAvailable
        }
        let deficeit = removeItem(by: itemType, with: quantity)
        owner?.updateMoney(by: (quantity - deficeit) * value)
        if deficeit > 0 {
            throw BuyItemError.insufficientItems(shortOf: deficeit)
        }
    }

    func endTurn(speedMultiplier: Double) {
        if isChasedByPirates {
            turnsToBeingCaught -= 1
        }

        for supply in suppliesConsumed {
            guard let parameter = supply.itemParameter else {
                continue
            }
            let type = supply.itemType
            let deficeit = removeItem(by: type, with: Int(Double(supply.quantity) * speedMultiplier))
            showMessage(titled: "Deficeit!", withMsg: "You have exhausted \(parameter.displayName) and have a deficeit of \(deficeit). Please pay for it.")
            owner?.updateMoney(by: -deficeit * parameter.getBuyValue())
        }

        // decay remaining items
        for item in items.value {
            guard let lostQuantity = item.decayItem(with: speedMultiplier) else {
                continue
            }
            showMessage(titled: "Lost Item", withMsg: "You have lost \(lostQuantity) of \(item.itemParameter?.displayName ?? "") from decay and have \(item.quantity) remaining!")
        }
    }

    // Helper functions

    private func computeMovement(roll: Int, speedMultiplier: Double) -> Double {
        var multiplier = 1.0
        multiplier = applyMovementModifiers(to: multiplier)
        return Double(roll) * speedMultiplier * multiplier
    }

    private func applyMovementModifiers(to multiplier: Double) -> Double {
        var result = multiplier
        result *= shipChassis?.getMovementModifier() ?? 1
        result *= auxiliaryUpgrade?.getMovementModifier() ?? 1
        return result
    }

    private func getRemainingCapacity() -> Int {
        return weightCapacity - currentCargoWeight
    }

    private func addItem(item: GenericItem) throws {
        let difference = getRemainingCapacity() - (item.weight ?? 0)
        guard difference >= 0 else {
            throw BuyItemError.insufficientFunds(shortOf: difference)
        }
        guard let sameType = items.value.first(where: { $0.itemParameter == item.itemParameter }) else {
            items.value.append(item)
            items.value = items.value
            return
        }
        _ = sameType.combine(with: item)
        return
    }

    private func removeItem(by itemType: ItemType, with quantity: Int) -> Int {
        guard let index = items.value.firstIndex(where: { $0.itemType == itemType }) else {
            return quantity
        }
        guard let item = items.value[index] as? GenericItem else {
            return 0
        }
        let deficit = item.remove(amount: quantity)
        if items.value[index].quantity == 0 {
            items.value.remove(at: index)
            items.value = items.value
        }
        guard deficit <= 0 else {
            return removeItem(by: itemType, with: deficit)
        }
        return 0
    }

    func getCurrentNode() -> Node {
        guard let map = map, let node = map.nodeIDPair[nodeId] else {
            fatalError("Ship does not reside on any map or nodeId is invalid.")
        }
        return node
    }

}

// MARK: - Observable values
extension Ship {
    func subscribeToLocation(with observer: @escaping (Node) -> Void) {
        nodeIdVariable.subscribe { [weak self] _ in
            guard let self = self else {
                return
            }
            guard let map = self.map, let node = map.nodeIDPair[self.nodeId] else {
                return
            }
            observer(node)
        }
    }

    func subscribeToItems(with observer: @escaping ([GenericItem]) -> Void) {
        items.subscribe(with: observer)
    }

    func subscribeToCargoWeight(with observer: @escaping (Int) -> Void) {
        currentCargoWeightVariable.subscribe(with: observer)
    }

    func subscribeToWeightCapcity(with observer: @escaping (Int) -> Void) {
        weightCapacityVariable.subscribe(with: observer)
    }

    private func updateCargoWeight(items: [GenericItem]) {
        var result = 0
        for item in items {
            result += item.weight ?? 0
        }
        currentCargoWeightVariable.value = result
    }
}

// MARK: - Show messages
// TODO remove interface
extension Ship {
    private func showMessage(titled: String, withMsg: String) {
        /*
        owner?.interface?.pauseAndShowAlert(titled: titled, withMsg: withMsg)
        owner?.interface?.broadcastInterfaceChanges(withDuration: 0.5)*/
    }
}

// MARK: - Affected by Pirates and Weather
extension Ship: Pirate_WeatherEntity {
    func startPirateChase() {
        isChasedByPirates = true
        turnsToBeingCaught = 2
        showMessage(titled: "Pirates!", withMsg: "You have ran into pirates! You must dock your ship within \(turnsToBeingCaught) turns or risk losing all your cargo!")
    }
    func getWeatherModifier() -> Double {
        var multiplier = 1.0
        multiplier *= shipChassis?.getWeatherModifier() ?? 1
        multiplier *= auxiliaryUpgrade?.getWeatherModifier() ?? 1
        return multiplier
    }
}
