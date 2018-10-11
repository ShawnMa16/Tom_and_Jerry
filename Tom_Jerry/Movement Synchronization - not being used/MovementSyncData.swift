//
//  MoveDataSync.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 10/2/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//
/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Top-level container for physics data sync between peers.
 */

import Foundation

struct MovementSyncData {
    
    var packetNumber: Int
    var nodeData: [MovementData]
    
    static let packetNumberBits = 12 // 12 bits represents packetNumber reset every minute
    static let nodeCountBits = 9
    static let maxPacketNumber = Int(pow(2.0, Double(packetNumberBits)))
    static let halfMaxPacketNumber = maxPacketNumber / 2
}

extension MovementSyncData: BitStreamCodable {
    
    func encode(to bitStream: inout WritableBitStream) throws {
        bitStream.appendUInt32(UInt32(packetNumber), numberOfBits: MovementSyncData.packetNumberBits)
        
        let nodeCount = nodeData.count
        bitStream.appendUInt32(UInt32(nodeCount), numberOfBits: MovementSyncData.nodeCountBits)
        for node in nodeData {
            try node.encode(to: &bitStream)
        }
    }
    
    init(from bitStream: inout ReadableBitStream) throws {
        packetNumber = Int(try bitStream.readUInt32(numberOfBits: MovementSyncData.packetNumberBits))
        
        let nodeCount = Int(try bitStream.readUInt32(numberOfBits: MovementSyncData.nodeCountBits))
        nodeData = []
        for _ in 0..<nodeCount {
            nodeData.append(try MovementData(from: &bitStream))
        }
    }
}
