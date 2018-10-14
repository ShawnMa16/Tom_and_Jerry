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
        let runningIdentifier = isHost ? "Jerry-Running-1" : "Tom-Running-1"
        
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
    var geometryNode: SCNNode!
    var shadowPlanNode: SCNNode?
    
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
        
        self.objectRootNode.castsShadow = true
//        self.geometryNode.castsShadow = true
        
        castShadow()
        
    }
    
    private func loadTom() -> SCNNode {
        
        let idleScene = SCNScene(named: "art.scnassets/Tom-Idle.dae")!
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
        // clone the object node to geometry node
        self.geometryNode = isHost ? loadJerry().clone() : loadTom().clone()
        self.objectRootNode.addChildNode(self.geometryNode)
    }
    
    private func castShadow() {
        let shadowPlane = SCNPlane(width: 20.0, height: 20.0)
        shadowPlane.materials.first?.colorBufferWriteMask = SCNColorMask(rawValue:0)
        self.shadowPlanNode = SCNNode(geometry: shadowPlane)
        self.shadowPlanNode!.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
        self.objectRootNode.addChildNode(self.shadowPlanNode!)
    }
    
    func swichAnimation(isMoving: Bool) {
        let beginKey = isMoving ? "running" : "idle"
        let stopKey = isMoving ? "idle" : "running"
        self.geometryNode.addAnimation(self.animations.animations[beginKey]!, forKey: beginKey)
        self.geometryNode.removeAnimation(forKey: stopKey, blendOutDuration: CGFloat(0.5))
    }
    
}
