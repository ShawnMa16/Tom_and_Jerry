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
    
    init(isHost: Bool, isAlive: Bool) {
        var idleSceneName = isHost ? "art.scnassets/Jerry-Idle" : "art.scnassets/Cheese_Idle"
        var runningSceneName = isHost ? "art.scnassets/Jerry-Running" : "art.scnassets/Cheese_Running"
        var idleIdentifier = isHost ? "Jerry-Idle-1" : "Cheese_Idle-1"
        var runningIdentifier = isHost ? "Jerry-Running-1" : "Cheese_Running-1"
        
        let lookBehindSceneName = "art.scnassets/Jerry-Look-Behind"
        let lookBehindIdentifier = "Jerry-Look-Behind-1"
        
        let tomCatchSceneName = "art.scnassets/Tom-Catching"
        let tomCatchIdentifier = "Tom-Catching-1"
        
        if !isAlive {
            idleSceneName = "art.scnassets/Tom-Idle"
            runningSceneName = "art.scnassets/Tom-Running"
            idleIdentifier = "Tom-Idle-1"
            runningIdentifier = "Tom-Running-1"
        }
        
        let idleURL = Bundle.main.url(forResource: idleSceneName, withExtension: "dae")!
        let runningURL = Bundle.main.url(forResource: runningSceneName, withExtension: "dae")!
        
        let lookBehindURL = Bundle.main.url(forResource: lookBehindSceneName, withExtension: "dae")!
        let tomCatchURL = Bundle.main.url(forResource: tomCatchSceneName, withExtension: "dae")!
        
        idleSceneSrouce = SCNSceneSource(url: idleURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        
        runningSceneSource = SCNSceneSource(url: runningURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        
        let lookBehindSceneSource = SCNSceneSource(url: lookBehindURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        let tomCatchSceneSrouce = SCNSceneSource(url: tomCatchURL, options: [
            SCNSceneSource.LoadingOption.animationImportPolicy : SCNSceneSource.AnimationImportPolicy.doNotPlay])!
        
        loadAnimations(sceneSource: idleSceneSrouce, withKey: "idle", animationIdentifier: idleIdentifier)
        loadAnimations(sceneSource: runningSceneSource, withKey: "running", animationIdentifier: runningIdentifier)
        
        if isHost {
            loadAnimations(sceneSource: lookBehindSceneSource, withKey: "lookBehind", animationIdentifier: lookBehindIdentifier)
        } else {
            loadAnimations(sceneSource: tomCatchSceneSrouce, withKey: "tomCatch", animationIdentifier: tomCatchIdentifier)
        }
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
    
    var isMoving: Bool = false
    
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
        
        self.animations = ObjectAnimations(isHost: isHost, isAlive: isAlive)
        
        super.init()
        
        attachGeometry(isHost: isHost)
        
        self.objectRootNode.castsShadow = true
        
        castShadow()
        
    }
    
    private func loadCheese() -> SCNNode {
        
        let idleScene = SCNScene(named: "art.scnassets/Cheese_Idle.dae")!
        let rootNode = SCNNode()
        
        for childNode in idleScene.rootNode.childNodes {
            rootNode.addChildNode(childNode)
        }
        return rootNode
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
        self.geometryNode = isHost ? loadJerry().clone() : loadCheese().clone()
        self.objectRootNode.addChildNode(self.geometryNode)
    }
    
    private func castShadow() {
        self.objectRootNode.castsShadow = true
        
        let shadowPlane = SCNPlane(width: 30.0, height: 30.0)
        shadowPlane.cornerRadius = 30
        shadowPlane.materials.first?.colorBufferWriteMask = SCNColorMask(rawValue:0)
        self.shadowPlanNode = SCNNode(geometry: shadowPlane)
        self.shadowPlanNode!.transform = SCNMatrix4MakeRotation(-Float.pi/2, 1, 0, 0)
        self.objectRootNode.addChildNode(self.shadowPlanNode!)
    }
    
    func switchBetweenIdleAndRunning(isMoving: Bool) {
        self.isMoving = isMoving
        
        let beginKey = isMoving ? "running" : "idle"
        let stopKey = isMoving ? "idle" : "running"
        self.geometryNode.addAnimation(self.animations.animations[beginKey]!, forKey: beginKey)
        self.geometryNode.removeAnimation(forKey: stopKey, blendOutDuration: CGFloat(0.5))
    }
    
    func shouldSwitchToTom() {
        self.geometryNode.removeAllAnimations()
        self.geometryNode.removeFromParentNode()
        
        self.geometryNode = nil
        self.shadowPlanNode = nil
        
        self.geometryNode = loadTom().clone()
        self.objectRootNode.addChildNode(self.geometryNode)
        
        self.animations = ObjectAnimations(isHost: false, isAlive: false)
    }
    
    func jerryLookBehind(isInRange: Bool, shouldPerform: Bool) {
        let lookBehind = "lookBehind"
        
        if self.isMoving, shouldPerform {
            if isInRange {
                self.geometryNode.addAnimation(self.animations.animations[lookBehind]!, forKey: lookBehind)
                self.geometryNode.removeAnimation(forKey: "running", blendOutDuration: CGFloat(0.5))
            } else {
                self.geometryNode.addAnimation(self.animations.animations["running"]!, forKey: "running")
                self.geometryNode.removeAnimation(forKey: lookBehind, blendOutDuration: CGFloat(0.5))
            }
        }
    }
    
    func tomCatch(isInRange: Bool, shouldPerform: Bool) {
        let tomCatch = "tomCatch"
        
        if self.isMoving, shouldPerform {
            if isInRange {
                self.geometryNode.addAnimation(self.animations.animations[tomCatch]!, forKey: tomCatch)
                self.geometryNode.removeAnimation(forKey: "running", blendOutDuration: CGFloat(0.5))
            } else {
                self.geometryNode.addAnimation(self.animations.animations["running"]!, forKey: "running")
                self.geometryNode.removeAnimation(forKey: tomCatch, blendOutDuration: CGFloat(0.5))
            }
        }
    }
    
    func perfromAction(isHost: Bool, isInRange: Bool) {
        let action = isHost ? "lookBehind" : "tomCatch"
        
        if self.isMoving{
            if isInRange {
                self.geometryNode.addAnimation(self.animations.animations[action]!, forKey: action)
                self.geometryNode.removeAnimation(forKey: "running", blendOutDuration: CGFloat(0.5))
            } else {
                self.geometryNode.addAnimation(self.animations.animations["running"]!, forKey: "running")
                self.geometryNode.removeAnimation(forKey: action, blendOutDuration: CGFloat(0.5))
            }
        }
    }
    
}
