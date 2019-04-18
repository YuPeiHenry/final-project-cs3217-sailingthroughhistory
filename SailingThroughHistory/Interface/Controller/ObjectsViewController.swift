//
//  ObjectsViewController.swift
//  SailingThroughHistory
//
//  Created by Jason Chong on 21/3/19.
//  Copyright © 2019 Sailing Through History Team. All rights reserved.
//

import UIKit

class ObjectsViewController {
    private var objectViews = [GameObject: UIImageView]()
    private weak var delegate: ObjectsViewControllerDelegate?
    private var nodeViews = [Int: NodeView]()
    private var paths = ObjectPaths()
    private var pathLayers = [Path: CAShapeLayer]()
    private var objectQueues = [GameObject: DispatchQueue]()
    private let view: UIView
    private var pathWeathers = [Path: UILightningView]()
    private var modelBounds: Rect

    init(view: UIView, modelBounds: Rect, delegate: ObjectsViewControllerDelegate) {
        self.view = view
        self.delegate = delegate
        self.modelBounds = modelBounds
    }

    func onTap(nodeView: NodeView) -> Int {
        if nodeView.node as? Port != nil {
            onTapPort(portView: nodeView)
        }

        return nodeView.node.identifier
    }

    func subscribeToNodes(in map: Map) {
        map.subscribeToNodes { [weak self] nodes in
            guard let self = self else {
                return
            }
            for node in nodes {
                if self.nodeViews[node.identifier] != nil {
                    continue
                }

                let nodeView = NodeView(node: node)
                nodeView.isUserInteractionEnabled = true
                nodeView.frame = CGRect.translatingFrom(otherBounds: self.modelBounds, otherFrame: node.frame,
                                                        to: self.view.bounds)
                self.view.addSubview(nodeView)
                self.nodeViews[node.identifier] = nodeView
            }
        }
    }

    func subscribeToPaths(in map: Map) {
        map.subscribeToPaths { [weak self] nodePaths in
            let mapPaths = Set(nodePaths.values.flatMap { $0 })
            guard let existingPaths = self?.paths.allPaths else {
                return
            }

            for path in mapPaths {
                if existingPaths.contains(path) {
                    return
                }

                guard let fromFrame = self?.nodeViews[path.fromNode.identifier]?.frame,
                    let toFrame = self?.nodeViews[path.toNode.identifier]?.frame else {
                        continue
                }

                self?.paths.add(path: path)
                self?.addToView(path: path, from: fromFrame, to: toFrame, withDuration: 1)
            }
        }
    }

    func make(choosableNodes: [Int]) {
        for nodeId in choosableNodes {
            guard let view = nodeViews[nodeId] else {
                return
            }

            view.addGlow(colored: .yellow)
        }
    }

    func resetChoosableNodes() {
        nodeViews.values
            .forEach {
                $0.removeGlow()
        }
    }

    private func addToView(path: Path, from fromFrame: CGRect,
                           to toFrame: CGRect, withDuration duration: TimeInterval) {
        let startPoint = CGPoint(x: fromFrame.midX, y: fromFrame.midY)
        let endPoint = CGPoint(x: toFrame.midX, y: toFrame.midY)
        let bezierPath = UIBezierPath()
        let layer = CAShapeLayer()
        bezierPath.drawArrow(from: startPoint, to: endPoint)
        layer.path = bezierPath.cgPath
        layer.strokeColor = UIColor.darkGray.cgColor
        layer.fillColor = UIColor.clear.cgColor
        layer.lineWidth = 4.0
        layer.lineDashPattern = [10.0, 2.0]
        view.layer.addSublayer(layer)
        pathLayers[path] = layer
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.fromValue = 0.0
        animation.toValue = 1.0
        animation.duration = duration
        layer.add(animation, forKey: "drawLineAnimation")
        let weatherView = UILightningViewFactory.getLightningView(frame: bezierPath.bounds)
        pathWeathers[path] = weatherView
        view.addSubview(weatherView)
        weatherView.initView()
    }

    func subscribeToObjects(in map: Map) {
        map.subscribeToObjects { [weak self] in
            guard let self = self else {
                return
            }
            var objects = [GameObject](self.objectViews.keys)
            for object in $0 {
                self.register(object: object)
                objects.removeAll { $0 == object }
            }
            for removedObject in objects {
                let objectView = self.objectViews[removedObject]
                objectView?.removeFromSuperview()
                self.objectViews[removedObject] = nil
            }
        }
    }

    func updatePathWeather() {
        for path in paths.allPaths {
            let isActive = path
                .modifiers
                .map { $0.isActive }
                .contains(true)
            if isActive {
                pathWeathers[path]?.start()
            } else {
                pathWeathers[path]?.stop()
            }
            pathLayers[path]?.strokeColor = (isActive ? UIColor.red : UIColor.darkGray).cgColor
        }
    }

    func makeShipGlow(for player: GenericPlayer) {
        for (object, view) in objectViews {
            guard let ship = object as? ShipUI else {
                continue
            }

            if ship == player.playerShip?.shipObject {
                view.addGlow(colored: .green)
            } else {
                view.removeGlow()
            }
        }
    }

    private func update(frame: Rect, for object: GameObject) {
        guard let objectView = objectViews[object] else {
            return
        }
        if objectQueues[object] == nil {
            let identifier = String(UInt(bitPattern: ObjectIdentifier(object)))
            objectQueues[object] = DispatchQueue(label: identifier)
        }
        self.objectQueues[object]?.async {
            let semaphore = DispatchSemaphore.init(value: 0)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else {
                    return
                }
                UIView.animate(withDuration: 1, delay: 0, options: .curveLinear, animations: {
                    let newFrame = CGRect.translatingFrom(otherBounds: self.modelBounds,
                                                          otherFrame: frame, to: self.view.bounds)
                    objectView.frame = newFrame
                }, completion: { _ in semaphore.signal() })
            }
            semaphore.wait()
        }
    }

    private func register(object: GameObject) {
        if self.objectViews[object] != nil {
            return
        }
        let objectFrame = CGRect.translatingFrom(otherBounds: self.modelBounds,
                                                 otherFrame: object.frame.value, to: self.view.bounds)
        let objectView = UIImageView(frame: objectFrame)
        object.subscibeToFrame { [weak self] frame in
            self?.update(frame: frame, for: object)
        }
        if let shipUI = object as? ShipUI {
            objectView.image = UIImage(named: Resources.Icon.ship)
            if let team = shipUI.ship?.owner?.team {
                let icon = Icon(image: UIImage(named: Resources.Flag.of(team)))
                icon.addIcon(to: objectView)
            }
        }
        if object as? NPC != nil {
            objectView.image = UIImage(named: Resources.Icon.npc)
        }
        self.objectViews[object] = objectView
        self.view.addSubview(objectView)
    }

    private func onTapPort(portView: NodeView) {
        guard let port = portView.node as? Port else {
            return
        }

        delegate?.showInformation(of: port)
    }

    private enum State {
        case chooseDestination
        case normal
    }
}
