//
//  MovementData.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 10/2/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import Foundation
import simd
import SceneKit

private let positionCompressor = FloatCompressor(minValue: -80.0, maxValue: 80.0, bits: 16)
private let eulerAnglesCompressor = FloatCompressor(minValue: -1.0, maxValue: 1.0, bits: 12)

// Below these delta values, node's linear/angular velocity will not sync across
private let positionDeltaToConsiderNotMoving: Float = 0.0002
private let orientationDeltaToConsiderNotMoving: Float = 0.002

struct MovementData: CustomStringConvertible {
    var isAlive = true
    var position = float3()
    var eulerAngles = float3()

    var description: String {
        let pos = position
        let eul = eulerAngles
        return "pos:\(pos.x),\(pos.y),\(pos.z), rot:\(eul.x),\(eul.y),\(eul.z)"
    }
    
}

extension MovementData {
    init(node: SCNNode, alive: Bool) {
        let newPosition = node.presentation.simdWorldPosition
        let newEulerAngles = node.presentation.simdEulerAngles
        
        position = newPosition
        eulerAngles = newEulerAngles
    }
}

extension MovementData: BitStreamCodable {
    
    func encode(to bitStream: inout WritableBitStream) throws {
        positionCompressor.write(position, to: &bitStream)
        eulerAnglesCompressor.write(eulerAngles, to: &bitStream)
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        position = try positionCompressor.readFloat3(from: &bitStream)
        eulerAngles = try eulerAnglesCompressor.readFloat3(from: &bitStream)
    }
}
