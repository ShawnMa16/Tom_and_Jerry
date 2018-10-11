//
//  ARJoystickSKScene.swift
//  ARJoystick
//
//  Created by Alex Nagy on 27/07/2018.
//  Copyright © 2018 Alex Nagy. All rights reserved.
//

import SpriteKit

class ARJoystickSKScene: SKScene {
    
    enum NodesZPosition: CGFloat {
        case joystick
    }
    
    lazy var analogJoystick: AnalogJoystick = {
        let js = AnalogJoystick(diameter: 100, colors: nil, images: (substrate: UIImage(named: "jSubstrate"), stick: UIImage(named: "jStick")))
        js.position = CGPoint(x: js.radius + 40, y: js.radius + 40)
        js.zPosition = NodesZPosition.joystick.rawValue
        return js
    }()
    
    override func didMove(to view: SKView) {
        self.backgroundColor = .clear
        setupNodes()
        setupJoystick()
    }
    
    func setupNodes() {
        anchorPoint = CGPoint(x: 0.0, y: 0.0)
    }
    
    func setupJoystick() {
        addChild(analogJoystick)
        
        analogJoystick.trackingHandler = { data in
            NotificationCenter.default.post(name: joystickMoving, object: nil, userInfo: ["data": data])
        }
        
        analogJoystick.beginHandler = {
            NotificationCenter.default.post(name: joystickBeginMoving, object: nil, userInfo: ["moving": true])
        }
        
        analogJoystick.stopHandler = {
            NotificationCenter.default.post(name: joystickEndMoving, object: nil, userInfo: ["moving": false])
        }
        
    }
    
}


















