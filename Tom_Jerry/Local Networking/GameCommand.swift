/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Representations for game events, related data, and their encoding.
 */

import Foundation
import simd
import SceneKit

/// - Tag: GameCommand
struct GameCommand {
    var player: Player?
    var action: Action
}

extension float3: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        self.init(x, y, z)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
    }
}

extension float4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        let w = try bitStream.readFloat()
        self.init(x, y, z, w)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
        bitStream.appendFloat(w)
    }
}

extension float4x4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self.init()
        self.columns.0 = try float4(from: &bitStream)
        self.columns.1 = try float4(from: &bitStream)
        self.columns.2 = try float4(from: &bitStream)
        self.columns.3 = try float4(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        columns.0.encode(to: &bitStream)
        columns.1.encode(to: &bitStream)
        columns.2.encode(to: &bitStream)
        columns.3.encode(to: &bitStream)
    }
}

extension String: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let data = try bitStream.readData()
        if let value = String(data: data, encoding: .utf8) {
            self = value
        } else {
            throw BitStreamError.encodingError
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        if let data = data(using: .utf8) {
            bitStream.append(data)
        } else {
            throw BitStreamError.encodingError
        }
    }
}

enum GameBoardLocation: BitStreamCodable {
    case worldMapData(Data)
    case manual
    
    enum CodingKey: UInt32, CaseIterable {
        case worldMapData
        case manual
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .worldMapData:
            let data = try bitStream.readData()
            self = .worldMapData(data)
        case .manual:
            self = .manual
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        switch self {
        case .worldMapData(let data):
            bitStream.appendEnum(CodingKey.worldMapData)
            bitStream.append(data)
        case .manual:
            bitStream.appendEnum(CodingKey.manual)
        }
    }
}

enum BoardSetupAction: BitStreamCodable {
    case requestBoardLocation
    case boardLocation(GameBoardLocation)
    
    enum CodingKey: UInt32, CaseIterable {
        case requestBoardLocation
        case boardLocation
        
    }
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .requestBoardLocation:
            self = .requestBoardLocation
        case .boardLocation:
            let location = try GameBoardLocation(from: &bitStream)
            self = .boardLocation(location)
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        switch self {
        case .requestBoardLocation:
            bitStream.appendEnum(CodingKey.requestBoardLocation)
        case .boardLocation(let location):
            bitStream.appendEnum(CodingKey.boardLocation)
            location.encode(to: &bitStream)
        }
    }
}


struct GameVelocity {
    var vector: float3
    static var zero: GameVelocity { return GameVelocity(vector: float3()) }
}

extension GameVelocity: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        vector = try float3(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        vector.encode(to: &bitStream)
    }
}

private let velocityCompressor = FloatCompressor(minValue: -50.0, maxValue: 50.0, bits: 16)
private let angularVelocityAxisCompressor = FloatCompressor(minValue: -1.0, maxValue: 1.0, bits: 12)

struct MoveData {
    var velocity: GameVelocity
    var angular: Float
}

extension MoveData: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        velocity = try GameVelocity(from: &bitStream)
        angular = try bitStream.readFloat()
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        velocity.encode(to: &bitStream)
        bitStream.appendFloat(angular)
    }
}

struct AddObjectAction {
    var simdWorldTransform: float4x4
    var eulerAngles: float3
}

struct SwitchAnimation {
    var isMoving: Bool
}

extension SwitchAnimation: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        isMoving = try bitStream.readBool()
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        bitStream.appendBool(isMoving)
    }
}

extension AddObjectAction: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        simdWorldTransform = try float4x4(from: &bitStream)
        eulerAngles = try float3(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        simdWorldTransform.encode(to: &bitStream)
        eulerAngles.encode(to: &bitStream)
    }
}

enum GameAction {
    case JoyStickInMoving(MoveData)
    case JoyStickWillorStopMoving(SwitchAnimation)
    
    private enum CodingKey: UInt32, CaseIterable {
        case move
        case swichAnimation
    }
}

extension GameAction: BitStreamCodable {
    
    func encode(to bitStream: inout WritableBitStream) throws {
        // switch game action
        switch self {
        case .JoyStickInMoving(let data):
            bitStream.appendEnum(CodingKey.move)
            try data.encode(to: &bitStream)
            
        case .JoyStickWillorStopMoving(let data):
            bitStream.appendEnum(CodingKey.swichAnimation)
            try data.encode(to: &bitStream)
        }
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        let key: CodingKey = try bitStream.readEnum()
        switch key {
        case .move:
            let data = try MoveData(from: &bitStream)
            self = .JoyStickInMoving(data)
        case .swichAnimation:
            let data = try SwitchAnimation(from: &bitStream)
            self = .JoyStickWillorStopMoving(data)
        }
    }
}

enum Action {
    case gameAction(GameAction)
    case boardSetup(BoardSetupAction)
    case addObject(AddObjectAction)
}

extension Action: BitStreamCodable {
    private enum CodingKey: UInt32, CaseIterable {
        case gameAction
        case boardSetup
        case addObject
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        switch self {
        case .gameAction(let gameAction):
            bitStream.appendEnum(CodingKey.gameAction)
            try gameAction.encode(to: &bitStream)
        case .boardSetup(let boardSetup):
            bitStream.appendEnum(CodingKey.boardSetup)
            boardSetup.encode(to: &bitStream)
        case .addObject(let addTankAction):
            bitStream.appendEnum(CodingKey.addObject)
            try addTankAction.encode(to: &bitStream)
        }
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        let code: CodingKey = try bitStream.readEnum()
        switch code {
        case .gameAction:
            let gameAction = try GameAction(from: &bitStream)
            self = .gameAction(gameAction)
        case .boardSetup:
            let boardAction = try BoardSetupAction(from: &bitStream)
            self = .boardSetup(boardAction)
        case .addObject:
            let addObjectAction = try AddObjectAction(from: &bitStream)
            self = .addObject(addObjectAction)
        }
    }
}
