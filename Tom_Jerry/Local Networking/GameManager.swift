//
//  GameManager.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 9/29/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import Foundation
import SceneKit
import GameplayKit
import simd
import ARKit
import AVFoundation
import os.signpost

protocol GameManagerDelegate: class {
    func manager(_ manager: GameManager, received: BoardSetupAction, from: Player)
    func manager(_ manager: GameManager, joiningPlayer player: Player)
    func manager(_ manager: GameManager, leavingPlayer player: Player)
    func manager(_ manager: GameManager, joiningHost host: Player)
    func manager(_ manager: GameManager, leavingHost host: Player)
    func managerDidStartGame(_ manager: GameManager)
    
    func manager(_ manager: GameManager, addTank: AddTankNodeAction)
}


/// - Tag: GameManager
class GameManager: NSObject {
    // don't execute any code from SCNView renderer until this is true
    private(set) var isInitialized = false
    
    private let session: NetworkSession?
    private var scene: SCNScene
    
    var gameObjects = Set<GameObject>()
    
    private let catapultsLock = NSLock()
    private var gameCommands = [GameCommand]()
    private let commandsLock = NSLock()
    
    private let movementSyncData = MovementSyncSceneData()
    
    let currentPlayer = UserDefaults.standard.myself
    
    let isNetworked: Bool
    let isServer: Bool
    
    init(sceneView: SCNView, session: NetworkSession?) {
        self.scene = sceneView.scene!
        self.session = session
        
        self.isNetworked = session != nil
        self.isServer = session?.isServer ?? true // Solo game act like a server
        
        super.init()
        
        self.session?.delegate = self
    }
    
    func queueAction(gameAction: GameAction) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        gameCommands.append(GameCommand(player: currentPlayer, action: .gameAction(gameAction)))
    }
    
//    private func syncMovement() {
//        os_signpost(.begin, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
//                    "Movement sync started")
//        defer { os_signpost(.end, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
//                            "Movement sync finished") }
//        
//        if isNetworked && movementSyncData.isInitialized {
//            if isServer {
//                let movementData = movementSyncData.generateData()
//                session?.send(action: .gameAction(.movement(movementData)))
//            } else {
//                movementSyncData.updateFromReceivedData()
//            }
//        }
//    }
    
    
    func resetWorld(sceneView: SCNView) {
        self.scene = sceneView.scene!
    }
    
    weak var delegate: GameManagerDelegate?
    
    func send(gameAction: GameAction) {
        session?.send(action: .gameAction(gameAction))
    }
    
    func send(addTankAction: AddTankNodeAction) {
        session?.send(action: .addTank(addTankAction))
    }
    
    func send(boardAction: BoardSetupAction) {
        session?.send(action: .boardSetup(boardAction))
    }
    
    func send(boardAction: BoardSetupAction, to player: Player) {
        session?.send(action: .boardSetup(boardAction), to: player)
    }
    
    // MARK: - inbound from network
    private func process(command: GameCommand) {
        os_signpost(.begin, log: .render_loop, name: .process_command, signpostID: .render_loop,
                    "Action : %s", command.action.description)
        defer { os_signpost(.end, log: .render_loop, name: .process_command, signpostID: .render_loop,
                            "Action : %s", command.action.description) }
        
        switch command.action {
        case .gameAction(let gameAction):
            // should controll tank here
            guard let player = command.player else { return }
            if case let .joyStickMoved(data) = gameAction {
                self.moveObject(player: player, movement: data)
            }
        case .boardSetup(let boardAction):
            if let player = command.player {
                delegate?.manager(self, received: boardAction, from: player)
            }
        case .addTank(let addTankAction):
            if let player = command.player {
                // should send create tank action here
                let tankNode = SCNNode()
                tankNode.simdWorldTransform = addTankAction.simdWorldTransform
                tankNode.eulerAngles = SCNVector3(addTankAction.eulerAngles.x, addTankAction.eulerAngles.y, addTankAction.eulerAngles.z)
                print(self.scene.rootNode.simdWorldTransform)
                tankNode.scale = SCNVector3(0.0002, 0.0002, 0.0002)
                self.createTank(tankNode: tankNode, owner: player)
            }
        }
    }
    
    // MARK: update
    // Called from rendering loop once per frame
    /// - Tag: GameManager-update
    func update(timeDelta: TimeInterval) {
        processCommandQueue()
    }
    
    private func processCommandQueue() {
        // retrieving the command should happen with the lock held, but executing
        // it should be outside the lock.
        // inner function lets us take advantage of the defer keyword
        // for lock management.
        func nextCommand() -> GameCommand? {
            commandsLock.lock(); defer { commandsLock.unlock() }
            if gameCommands.isEmpty {
                return nil
            } else {
                return gameCommands.removeFirst()
            }
        }
        
        while let command = nextCommand() {
            process(command: command)
        }
    }
    
    func start() {
        // Start advertising game
        if let session = session, session.isServer {
            session.startAdvertising()
        }
        
        delegate?.managerDidStartGame(self)
        isInitialized = true
    }
    
    // game object managing
    func createTank(tankNode: SCNNode, owner: Player?) {
        let tank = GameObject(node: tankNode, index: 0, alive: true, owner: owner, isHost: currentPlayer == session?.host)
        // insert new Tank() to game scene
        self.gameObjects.insert(tank)
        DispatchQueue.main.async {
            self.scene.rootNode.addChildNode(tankNode)
        }
    }
    
    func moveObject(player: Player, movement: MoveData) {
        let object = self.gameObjects.filter { $0.owner == player}.first!
        
        let x = object.objectRootNode.position.x + movement.velocity.vector.x * Float(joystickVelocityMultiplier)
        let y = object.objectRootNode.position.y + movement.velocity.vector.y * Float(joystickVelocityMultiplier)
        let z = object.objectRootNode.position.z - movement.velocity.vector.y * Float(joystickVelocityMultiplier)
        
        let angular = movement.angular
        
        object.objectRootNode.position = SCNVector3(x: x, y: y, z: z)
        object.objectRootNode.eulerAngles.y = angular + Float(180.0 * .pi / 180)
    }
    
    func swtchAnimation(player: Player, isMoving: Bool) {
        let object = self.gameObjects.filter { $0.owner == player}.first!
        
        object.swichAnimation(isIdle: isMoving)
    }
    
}

extension GameManager: NetworkSessionDelegate {
    func networkSession(_ session: NetworkSession, received command: GameCommand) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        if case Action.gameAction(.joyStickMoved(_)) = command.action {
            gameCommands.append(command)
        } else {
            process(command: command)
        }
    }
    
    func networkSession(_ session: NetworkSession, joining player: Player) {
        if player == session.host {
            delegate?.manager(self, joiningHost: player)
        } else {
            delegate?.manager(self, joiningPlayer: player)
        }
    }
    
    func networkSession(_ session: NetworkSession, leaving player: Player) {
        if player == session.host {
            delegate?.manager(self, leavingHost: player)
        } else {
            delegate?.manager(self, leavingPlayer: player)
        }
    }
    
}
