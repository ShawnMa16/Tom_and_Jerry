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
    
    func manager(_ manager: GameManager, addTank: AddObjectAction)
}


/// - Tag: GameManager
class GameManager: NSObject {
    // don't execute any code from SCNView renderer until this is true
    private(set) var isInitialized = false
    
    private let session: NetworkSession?
    private var scene: SCNScene
    
    private var shadowPlanNode: SCNNode?
    private var secondaryLightNode: SCNNode?
    private var mainLightNode: SCNNode?
    private var ambientLightNode: SCNNode?
    
    var gameObjects = Set<GameObject>()
    
    private let catapultsLock = NSLock()
    private var gameCommands = [GameCommand]()
    private let commandsLock = NSLock()
    
    private var shoudGameOver = false
    
    let currentPlayer = UserDefaults.standard.myself
    
    let isNetworked: Bool
    let isServer: Bool
    
    weak var gameIsOverDelegate: GameViewControllerDelegate?
    
    init(sceneView: SCNView, session: NetworkSession?) {
        self.scene = sceneView.scene!
        self.session = session
        
        self.isNetworked = session != nil
        self.isServer = session?.isServer ?? true // Solo game act like a server
        
        super.init()
        
        self.session?.delegate = self
    }
    
    private func setupLight() {
        
        // create secondary light
        secondaryLightNode = SCNNode()
        secondaryLightNode!.light = SCNLight()
        secondaryLightNode!.light!.type = .omni
        secondaryLightNode!.position = SCNVector3(x: 0, y: 1, z: 1)
        self.scene.rootNode.addChildNode(secondaryLightNode!)
        
        mainLightNode = SCNNode()
        mainLightNode!.light = SCNLight()
        mainLightNode!.light!.type = .spot
        mainLightNode!.light!.castsShadow = true
        mainLightNode!.light!.shadowMode = .deferred
        mainLightNode!.position = SCNVector3(x: -6, y: 10, z: 1)
        mainLightNode!.eulerAngles = SCNVector3(-Float.pi/2, 0, Float.pi/8)
        mainLightNode!.light!.shadowSampleCount = 64 //remove flickering of shadow and soften shadow
        mainLightNode!.light!.shadowMapSize = CGSize(width: 4096, height: 4096)
        self.scene.rootNode.addChildNode(mainLightNode!)
        
        ambientLightNode = SCNNode()
        ambientLightNode!.light = SCNLight()
        ambientLightNode!.light!.type = .ambient
        ambientLightNode!.light!.color = UIColor.darkGray
        self.scene.rootNode.addChildNode(ambientLightNode!)
    }
    
    func updateLighting(lightEstimate: ARLightEstimate) {
        self.ambientLightNode!.light!.intensity = lightEstimate.ambientIntensity
        self.ambientLightNode!.light!.temperature = lightEstimate.ambientColorTemperature
        self.secondaryLightNode!.light!.intensity = lightEstimate.ambientIntensity/3
        self.secondaryLightNode!.light!.temperature = lightEstimate.ambientColorTemperature
    }
    
    func queueAction(gameAction: GameAction) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        gameCommands.append(GameCommand(player: currentPlayer, action: .gameAction(gameAction)))
    }
    
    func resetWorld(sceneView: SCNView) {
        self.scene = sceneView.scene!
    }
    
    weak var delegate: GameManagerDelegate?
    
    func send(gameAction: GameAction) {
        session?.send(action: .gameAction(gameAction))
    }
    
    func send(addObjectAction: AddObjectAction) {
        session?.send(action: .addObject(addObjectAction))
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
            if case let .JoyStickInMoving(data) = gameAction {
                self.moveObject(player: player, movement: data)
            } else if case let .JoyStickWillorStopMoving(data) = gameAction {
                self.switchAnimation(player: player, isMoving: data.isMoving)
            }
        case .boardSetup(let boardAction):
            if let player = command.player {
                delegate?.manager(self, received: boardAction, from: player)
            }
        case .addObject(let addObjectAction):
            if let player = command.player {
                // should send create tank action here
                DispatchQueue.main.async {
                    self.createObject(addNodeAction: addObjectAction, owner: player)
                }
            }
        }
    }
    
    // MARK: update
    // Called from rendering loop once per frame
    /// - Tag: GameManager-update
    func update(timeDelta: TimeInterval) {
        processCommandQueue()
        
        if self.gameObjects.count > 1 {
            switchToTom()
            gameOver(self.shoudGameOver)
        }
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
    
    func startGame() {
        // Start advertising game
        if let session = session, session.isServer {
            session.startAdvertising()
        }
        
        delegate?.managerDidStartGame(self)
        isInitialized = true
        
        setupLight()
    }
    
    // game object managing
    
    func createObject(addNodeAction: AddObjectAction?, owner: Player?) {
        
        if let action = addNodeAction {
            let objectNode = SCNNode()
            objectNode.simdWorldTransform = action.simdWorldTransform
            objectNode.eulerAngles = SCNVector3(action.eulerAngles.x, action.eulerAngles.y, action.eulerAngles.z)
            objectNode.scale = SCNVector3(0.02, 0.02, 0.02)
            
            let object = GameObject(node: objectNode, index: 0, alive: action.isAlive, owner: owner, isHost: owner! == session?.host)
            
            self.gameObjects.insert(object)
            
            self.scene.rootNode.addChildNode(object.objectRootNode)
        }
    }
    
    func moveObject(player: Player, movement: MoveData) {
        let object = self.gameObjects.filter { $0.owner == player}.first!
        
        let x = object.objectRootNode.simdPosition.x + movement.velocity.vector.x * Float(joystickVelocityMultiplier)
        let y = object.objectRootNode.simdPosition.y
        let z = object.objectRootNode.simdPosition.z - movement.velocity.vector.y * Float(joystickVelocityMultiplier)
        let angular = movement.angular
        object.objectRootNode.simdPosition = float3(x: x, y: y, z: z)
        
        object.objectRootNode.eulerAngles.y = angular + Float(180.0.degreesToRadians)
    }
    
    func switchAnimation(player: Player, isMoving: Bool) {
        let object = self.gameObjects.filter { $0.owner == player}.first!
        
        object.swichAnimation(isMoving: isMoving)
    }
    
    
    private func shouldSwichToTom() -> Bool {
        let host = self.gameObjects.filter { $0.owner == session?.host}.first!
        let nonHost = self.gameObjects.filter { $0.owner != session?.host}.first!
        
        let distance = host.objectRootNode.simdPosition - nonHost.objectRootNode.simdPosition
        let length = sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
        
        if length < 0.4 && nonHost.isAlive {
            nonHost.isAlive = false
            return true
        } else {return false}
    }
    
    private func switchToTom() {
        if shouldSwichToTom() {
            let nonHost = self.gameObjects.filter { $0.owner != session?.host}.first!
            if !nonHost.isAlive {
                DispatchQueue.main.async {
                    let geometryNode = nonHost.objectRootNode!
                    self.createExplosion(position: geometryNode.presentation.position,
                                         rotation: geometryNode.presentation.rotation)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5)  {
                    nonHost.shouldSwitchToTom()
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { // change 2 to desired number of seconds
                    // Your code with delay
                    self.shoudGameOver = true
                }
            }

        }
    }
    
    private func gameOver(_ shouldStartEndingGame: Bool) {
        
        if shouldStartEndingGame {
            let host = self.gameObjects.filter { $0.owner == session?.host}.first!
            let nonHost = self.gameObjects.filter { $0.owner != session?.host}.first!
            
            let distance = host.objectRootNode.simdPosition - nonHost.objectRootNode.simdPosition
            let length = sqrtf(distance.x * distance.x + distance.y * distance.y + distance.z * distance.z)
            
            if length < 0.4 {
                gameIsOverDelegate?.gameIsOver()
            }
        }
    }
    
    //particle explosion effect
    private func createExplosion(position: SCNVector3, rotation: SCNVector4) {
        let explosion =
            SCNParticleSystem(named: "Explode.scnp", inDirectory:
                "./art.scnassets/Particles")!
        //explosion.emitterShape = geometry
        explosion.birthLocation = .surface
        
        let rotationMatrix =
            SCNMatrix4MakeRotation(rotation.w, rotation.x,
                                   rotation.y, rotation.z)
        let translationMatrix =
            SCNMatrix4MakeTranslation(position.x, position.y,
                                      position.z)
        let transformMatrix =
            SCNMatrix4Mult(rotationMatrix, translationMatrix)
        
        scene.addParticleSystem(explosion, transform:
            transformMatrix)
    }
    
}

extension GameManager: NetworkSessionDelegate {
    func networkSession(_ session: NetworkSession, received command: GameCommand) {
        commandsLock.lock(); defer { commandsLock.unlock() }
        if case Action.gameAction(.JoyStickInMoving(_)) = command.action {
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
