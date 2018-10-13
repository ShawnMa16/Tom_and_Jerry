//
//  Tank.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 9/30/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import Foundation
import SceneKit
import GameplayKit
import os.log

struct ObjectAnimations {
    let idleSceneSrouce: SCNSceneSource
    let runningSceneSource: SCNSceneSource
    
    var animations = [String: CAAnimation]()
    
    init(isHost: Bool) {
        let idleSceneName = isHost ? "art.scnassets/Jerry-Idle" : "art.scnassets/Tom-Idle"
        let runningSceneName = isHost ? "art.scnassets/Jerry-Running" : "art.scnassets/Tom-Running"
        let idleIdentifier = isHost ? "Jerry-Idle-1" : "Tom-Idle-1"
        let runningIdentifier = isHost ? "Jerry-Running-1" : "Tom-Runnning-1"
        
        let idleURL = Bundle.main.url(forResource: idleSceneName, withExtension: "dae")!
        let runningURL = Bundle.main.url(forResource: runningSceneName, withExtension: "dae")!
        
        idleSceneSrouce = SCNSceneSource(url: idleURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        
        runningSceneSource = SCNSceneSource(url: runningURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        
        
        loadAnimations(sceneSource: idleSceneSrouce, withKey: "idle", animationIdentifier: idleIdentifier)
        loadAnimations(sceneSource: runningSceneSource, withKey: "running", animationIdentifier: runningIdentifier)
    }
    
    private mutating func loadAnimations(sceneSource: SCNSceneSource?, withKey: String, animationIdentifier: String) {
        if let animationObject = sceneSource?.entryWithIdentifier(animationIdentifier, withClass: CAAnimation.self) {
            // loop the animation
            animationObject.repeatCount = Float.greatestFiniteMagnitude

            // To create smooth transitions between animations
            animationObject.fadeInDuration = CGFloat(1)
            animationObject.fadeOutDuration = CGFloat(0.5)
            
            // Store the animation for later use
            animations[withKey] = animationObject
        }
    }
}

class GameObject: NSObject {
    
    var objectRootNode: SCNNode!
    var physicsNode: SCNNode?
    var geometryNode: SCNNode?
//    var shadowPlanNode: SCNNode?
    
    var owner: Player?
    
    var animations: ObjectAnimations
    
    var isAlive: Bool
    
    static var indexCounter = 0
    var index = 0
    
    init(node: SCNNode, index: Int?, alive: Bool, owner: Player?, isHost: Bool) {
        objectRootNode = node
        self.isAlive = alive
        self.owner = owner
        
        if let index = index {
            self.index = index
        } else {
            self.index = GameObject.indexCounter
            GameObject.indexCounter += 1
        }
        
        self.animations = ObjectAnimations(isHost: isHost)
        
        super.init()
        
        attachGeometry(isHost: isHost)
        
//        self.objectRootNode.castsShadow = true
        
    }
    
    private func loadTank() -> SCNNode {
        let sceneURL = Bundle.main.url(forResource: "Tank", withExtension: "scn", subdirectory: "Assets.scnassets/Models")!
        let referenceNode = SCNReferenceNode(url: sceneURL)!
        referenceNode.load()
        
        return referenceNode
    }
    
    private func loadTom() -> SCNNode {
        let idleScene = SCNScene(named: "art.scnassets/running.dae")!
        let rootNode = SCNNode()
        
        for childNode in idleScene.rootNode.childNodes {
            rootNode.addChildNode(childNode)
        }
        return rootNode
    }
    
    private func loadJerry() -> SCNNode {
        let idleScene = SCNScene(named: "art.scnassets/Jerry-Idle.dae")!
        let rootNode = SCNNode()
        
        for childNode in idleScene.rootNode.childNodes {
            rootNode.addChildNode(childNode)
        }
        return rootNode
    }
    
    private func attachGeometry(isHost: Bool) {
        self.geometryNode = isHost ? loadJerry() : loadTom()
//        self.geometryNode = loadTank()
        self.objectRootNode.addChildNode(self.geometryNode!)
    }
    
//    private func castShadow() {
//        let shadowPlane = SCNPlane(width: 2.0, height: 2.0)
//        
//    }
    
    func swichAnimation(isIdle: Bool) {
        let beginKey = isIdle ? "running" : "idle"
        let stopKey = isIdle ? "idle" : "running"
        self.objectRootNode.removeAnimation(forKey: stopKey, blendOutDuration: CGFloat(0.5))
        self.objectRootNode.addAnimation(self.animations.animations[beginKey]!, forKey: beginKey)
        
//        self.objectRootNode.runAction(<#T##action: SCNAction##SCNAction#>)
    }
    
    func apply(movementData nodeData: MovementData, isHalfway: Bool) {
        // if we're not alive, avoid applying physics updates.
        // this will allow objects on clients to get culled properly
        guard isAlive else { return }
        
        if isHalfway {
            objectRootNode.simdWorldPosition = (nodeData.position + objectRootNode.simdWorldPosition) * 0.5
            objectRootNode.simdEulerAngles = (nodeData.eulerAngles + objectRootNode.simdEulerAngles) * 0.5
        } else {
            objectRootNode.simdWorldPosition = nodeData.position
            objectRootNode.simdEulerAngles = nodeData.eulerAngles
        }
    }
    
    func generateMovementData() -> MovementData? {
        return objectRootNode.map { MovementData(node: $0, alive: isAlive) }
    }
}
