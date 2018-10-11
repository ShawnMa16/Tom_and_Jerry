//
//  Constants.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 9/22/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import UIKit
import SceneKit
import CoreGraphics

var joystickMoving = NSNotification.Name("joystickMoving")
var joystickBeginMoving = NSNotification.Name("joystickBeginMoving")
var joystickEndMoving = NSNotification.Name("joystickEndMoving")

let joystickVelocityMultiplier: CGFloat = 0.00006

extension FloatingPoint {
    var degreesToRadians: Self { return self * .pi / 180 }
    var radiansToDegrees: Self { return self * 180 / .pi }
}
