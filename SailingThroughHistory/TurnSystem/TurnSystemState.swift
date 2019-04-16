//
//  TurnSystemState.swift
//  SailingThroughHistory
//
//  Created by Herald on 27/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

// A class used to hold the state of the turn based game
class TurnSystemState: GenericTurnSystemState {
    private var events: [Int: TurnSystemEvent] = [Int: TurnSystemEvent]()
    private var actionHistory = [(player: GenericPlayer, action: PlayerAction)]()
    let gameState: GenericGameState
    var currentPlayerIndex = 0
    var currentTurn: Int

    init(gameState: GenericGameState, joinOnTurn: Int) {
        self.gameState = gameState
        self.currentTurn = joinOnTurn
    }

    private var triggeredEventsDict: [Int: TurnSystemEvent] = [Int: TurnSystemEvent]()
    var triggeredEvents: [TurnSystemEvent] {
        return Array(triggeredEventsDict.values)
    }

    func addEvents(events: [TurnSystemEvent]) -> Bool {
        var result: Bool = true
        for event in events {
            if self.events[event.identifier] != nil {
                result = false
                continue
            }
            self.events[event.identifier] = event
        }
        return result
    }

    func removeEvents(events: [TurnSystemEvent]) -> Bool {
        var result: Bool = true
        for event in events {
            if self.events[event.identifier] == nil {
                result = false
                continue
            }
            self.events[event.identifier] = nil
        }
        return result
    }
    func setEvents(events: [TurnSystemEvent]) -> Bool {
        return removeEvents(events: Array(self.events.values))
            && addEvents(events: events)
    }

    func checkForEvents() -> [GameMessage] {
        var result = [GameMessage]()
        for (_, event) in events {
            guard let eventResult = event.evaluateEvent() else {
                continue
            }
            result.append(eventResult)
        }
        return result
    }

    func turnFinished() {
        currentTurn += 1
        gameState.gameTime.value.addWeeks(4)
    }

    // marked for deprecation
    func processed(action: PlayerAction, from player: GenericPlayer) {
        actionHistory.append((player: player, action: action))
    }
}