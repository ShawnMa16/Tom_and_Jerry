//
//  NetworkSession.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 9/27/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import simd
import ARKit
import os.signpost

protocol NetworkSessionDelegate: class {
    func networkSession(_ session: NetworkSession, received command: GameCommand)
    func networkSession(_ session: NetworkSession, joining player: Player)
    func networkSession(_ session: NetworkSession, leaving player: Player)
}

// kMCSessionMaximumNumberOfPeers is the maximum number in a session; because we only track
// others and not ourself, decrement the constant for our purposes.
private let maxPeers = kMCSessionMaximumNumberOfPeers - 1
//
class NetworkSession: NSObject {

    let myself: Player
    private var peers: Set<Player> = []
    
    let isServer: Bool
    let session: MCSession
    let host: Player
    
    let appIdentifier: String
    
    weak var delegate: NetworkSessionDelegate?
    
    private var serviceAdvertiser: MCNearbyServiceAdvertiser!
    private var serviceBrowser: MCNearbyServiceBrowser!
    
    init(myself: Player, asServer: Bool, host: Player) {
        self.myself = myself
        self.session = MCSession(peer: myself.peerID, securityIdentity: nil, encryptionPreference: .required)
        self.isServer = asServer
        self.host = host
        // if the appIdentifier is missing from the main bundle, that's
        // a significant build error and we should crash.
        self.appIdentifier = Bundle.main.appIdentifier!
        os_log("my appIdentifier is %s", self.appIdentifier)
        
        super.init()
        
        self.session.delegate = self
        
    }
    
    
    // for use when acting as game server
    func startAdvertising() {
        guard serviceAdvertiser == nil else { return } // already advertising
        
        os_log(.info, "ADVERTISING %@", myself.peerID)
        let discoveryInfo: [String: String] = [MultiuserAttribute.appIdentifier: appIdentifier]
        let advertiser = MCNearbyServiceAdvertiser(peer: myself.peerID,
                                                   discoveryInfo: discoveryInfo,
                                                   serviceType: MultiuserService.playerService)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        serviceAdvertiser = advertiser
    }
    
    func stopAdvertising() {
        os_log(.info, "stop advertising")
        serviceAdvertiser?.stopAdvertisingPeer()
        serviceAdvertiser = nil
    }
    
    // MARK: Actions
    func send(action: Action) {
        guard !peers.isEmpty else { return }
        do {
            var bits = WritableBitStream()
            try action.encode(to: &bits)
            let data = bits.packData()
            let peerIds = peers.map { $0.peerID }
            try session.send(data, toPeers: peerIds, with: .reliable)
            if action.description != "physics" {
                os_signpost(.event, log: .network_data_sent, name: .network_action_sent, signpostID: .network_data_sent,
                            "Action : %s", action.description)
            } else {
                let bytes = Int32(exactly: data.count) ?? Int32.max
                os_signpost(.event, log: .network_data_sent, name: .network_physics_sent, signpostID: .network_data_sent,
                            "%d Bytes Sent", bytes)
            }
        } catch {
            os_log(.error, "sending failed: %s", "\(error)")
        }
    }
    
    func send(action: Action, to player: Player) {
        do {
            var bits = WritableBitStream()
            try action.encode(to: &bits)
            let data = bits.packData()
            if data.count > 10_000 {
                try sendLarge(data: data, to: player.peerID)
            } else {
                try sendSmall(data: data, to: player.peerID)
            }
            if action.description != "physics" {
                os_signpost(.event, log: .network_data_sent, name: .network_action_sent, signpostID: .network_data_sent,
                            "Action : %s", action.description)
            } else {
                let bytes = Int32(exactly: data.count) ?? Int32.max
                os_signpost(.event, log: .network_data_sent, name: .network_physics_sent, signpostID: .network_data_sent,
                            "%d Bytes Sent", bytes)
            }
        } catch {
            os_log(.error, "sending failed: %s", "\(error)")
        }
    }
    
    func sendSmall(data: Data, to peer: MCPeerID) throws {
        try session.send(data, toPeers: [peer], with: .reliable)
    }
    
    func sendLarge(data: Data, to peer: MCPeerID) throws {
        let fileName = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: fileName)
        session.sendResource(at: fileName, withName: "Action", toPeer: peer) { error in
            if let error = error {
                os_log(.error, "sending failed: %s", "\(error)")
                return
            }
            os_log(.info, "send succeeded, removing temp file")
            do {
                try FileManager.default.removeItem(at: fileName)
            } catch {
                os_log(.error, "removing failed: %s", "\(error)")
            }
        }
    }
    
    func receive(data: Data, from peerID: MCPeerID) {
        guard let player = peers.first(where: { $0.peerID == peerID }) else {
            os_log(.info, "peer %@ unknown!", peerID)
            return
        }
        do {
            var bits = ReadableBitStream(data: data)
            let action = try Action(from: &bits)
            let command = GameCommand(player: player, action: action)
            delegate?.networkSession(self, received: command)
            
            if action.description != "physics" {
                os_signpost(.event, log: .network_data_received, name: .network_action_received, signpostID: .network_data_received,
                            "Action : %s", action.description)
            } else {
                let peerID = Int32(truncatingIfNeeded: peerID.displayName.hashValue)
                let bytes = Int32(exactly: data.count) ?? Int32.max
                os_signpost(.event, log: .network_data_received, name: .network_physics_received, signpostID: .network_data_received,
                            "%d Bytes Sent from %d", bytes, peerID)
            }
        } catch {
            os_log(.error, "deserialization error: %s", "\(error)")
        }
    }
    
}

extension NetworkSession: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        os_log(.info, "peer %@ state is now %d", peerID, state.rawValue)
        let player = Player(peerID: peerID)
        switch state {
        case .connected:
            peers.insert(player)
            delegate?.networkSession(self, joining: player)
        case .connecting:
            break
        case.notConnected:
            peers.remove(player)
            delegate?.networkSession(self, leaving: player)
        }
        // on the server, check to see if we're at the max number of players
        guard isServer else { return }
        if peers.count >= maxPeers {
            stopAdvertising()
        } else {
            startAdvertising()
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receive(data: data, from: peerID)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        os_log(.info, "peer %@ sent a stream named %s", peerID, streamName)
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        os_log(.info, "peer %@ started sending a resource named %s", peerID, resourceName)
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        os_log(.info, "peer %@ finished sending a resource named %s", peerID, resourceName)
        if let error = error {
            os_log(.error, "failed to receive resource: %s", "\(error)")
            return
        }
        guard let url = localURL else { os_log(.error, "what what no url?"); return }
        
        do {
            // .mappedIfSafe makes the initializer attempt to map the file directly into memory
            // using mmap(2), rather than serially copying the bytes into memory.
            // this is faster and our app isn't charged for the memory usage.
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            receive(data: data, from: peerID)
            // removing the file is done by the session, so long as we're done with it before the
            // delegate method returns.
        } catch {
            os_log(.error, "dealing with resource failed: %s", "\(error)")
        }
    }
}


extension NetworkSession: MCNearbyServiceBrowserDelegate {
    
    /// - Tag: FoundPeer
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // Invite the new peer to the session.
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // This app doesn't do anything with non-invited peers, so there's nothing to do here.
    }
    
}

extension NetworkSession: MCNearbyServiceAdvertiserDelegate {
    
    /// - Tag: AcceptInvite
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // Call handler to accept invitation and join the session.
        invitationHandler(true, self.session)
    }
    
}
