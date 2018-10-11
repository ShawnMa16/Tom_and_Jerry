//
//  MovementSyncSceneData.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 10/4/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//
/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Container for scene-level physics sync data.
 */

import Foundation
import simd
import SceneKit
import os.log

protocol MovementSyncSceneDataDelegate: class {
    func hasNetworkDelayStatusChanged(hasNetworkDelay: Bool)
}

class MovementSyncSceneData {
    private let lock = NSLock() // need thread protection because add used in main thread, while pack used in render update thread
    
    // Non-projectile sync
    private var objectList = [GameObject]()
    private var nodeDataList = [MovementData]()
    
    // Put data into queue to help with stutters caused by data packet delays
    private var packetQueue = [MovementSyncData]()
    
    private let maxPacketCount = 8
    private let packetCountToSlowDataUsage = 4
    private var shouldRefillPackets = true
    private var justUpdatedHalfway = false
    private var packetReceived = 0
    
    weak var delegate: MovementSyncSceneDataDelegate?
    var isInitialized: Bool { return delegate != nil }
    
    // Network Delay
    private(set) var hasNetworkDelay = false
    private var lastNetworkDelay = TimeInterval(0.0)
    private let networkDelayStatusLifetime = 3.0
    
    // Put up a packet number to make sure that packets are in order
    private var lastPacketNumberRead = 0
    
    func addObject(_ object: GameObject) {
        guard let data = object.generateMovementData() else { return }
        lock.lock() ; defer { lock.unlock() }
        objectList.append(object)
        nodeDataList.append(data)
    }
    
    func generateData() -> MovementSyncData {
        lock.lock() ; defer { lock.unlock() }
        // Update Data of normal nodes
        for index in 0..<objectList.count {
            if let data = objectList[index].generateMovementData() {
                nodeDataList[index] = data
            }
        }
        
        // Packet number is used to determined the order of sync data.
        // Because Multipeer Connectivity does not guarantee the order of packet delivery,
        // we use the packet number to discard out of order packets.
        let packetNumber = GameTime.frameCount % MovementSyncData.maxPacketNumber
        let packet = MovementSyncData(packetNumber: packetNumber, nodeData: nodeDataList)
        
        return packet
    }
    
    func updateFromReceivedData() {
        lock.lock() ; defer { lock.unlock() }
        discardOutOfOrderData()
        
        if shouldRefillPackets {
            if packetQueue.count >= maxPacketCount {
                shouldRefillPackets = false
            }
            return
        }
        
        if let oldestData = packetQueue.first {
            // Case when running out of data: Use one packet for two frames
            if justUpdatedHalfway {
                updateObjectsFromData(isHalfway: false)
                justUpdatedHalfway = false
            } else if packetQueue.count <= packetCountToSlowDataUsage {
                if !justUpdatedHalfway {
                    apply(packet: oldestData)
                    packetQueue.removeFirst()
                    
                    updateObjectsFromData(isHalfway: true)
                    justUpdatedHalfway = true
                }
                
                // Case when enough data: Use one packet per frame as usual
            } else {
                apply(packet: oldestData)
                packetQueue.removeFirst()
            }
            
        } else {
            shouldRefillPackets = true
            os_log(.info, "out of packets")
            
            // Update network delay status used to display in sceneViewController
            if !hasNetworkDelay {
                delegate?.hasNetworkDelayStatusChanged(hasNetworkDelay: true)
            }
            hasNetworkDelay = true
            lastNetworkDelay = GameTime.time
        }
        
        while packetQueue.count > maxPacketCount {
            packetQueue.removeFirst()
        }
        
        // Remove networkDelay status after time passsed without a delay
        if hasNetworkDelay && GameTime.time - lastNetworkDelay > networkDelayStatusLifetime {
            delegate?.hasNetworkDelayStatusChanged(hasNetworkDelay: false)
            hasNetworkDelay = false
        }
    }
    
    func receive(packet: MovementSyncData) {
        lock.lock(); defer { lock.unlock() }
        packetQueue.append(packet)
        packetReceived += 1
    }
    
    private func apply(packet: MovementSyncData) {
        lastPacketNumberRead = packet.packetNumber
        nodeDataList = packet.nodeData
        
        updateObjectsFromData(isHalfway: false)
    }
    
    private func updateObjectsFromData(isHalfway: Bool) {
        // Update Nodes
        let objectCount = min(objectList.count, nodeDataList.count)
        for index in 0..<objectCount where nodeDataList[index].isAlive {
            objectList[index].apply(movementData: nodeDataList[index], isHalfway: isHalfway)
        }
        
    }
    
    private func discardOutOfOrderData() {
        // Discard data that are out of order
        while let oldestData = packetQueue.first {
            let packetNumber = oldestData.packetNumber
            // If packet number of more than last packet number, then it is in order.
            // For the edge case where packet number resets to 0 again, we test if the difference is more than half the max packet number.
            if packetNumber > lastPacketNumberRead ||
                ((lastPacketNumberRead - packetNumber) > MovementSyncData.halfMaxPacketNumber) {
                break
            } else {
                os_log(.error, "Packet out of order")
                packetQueue.removeFirst()
            }
        }
    }
}
