/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Identifies a networked game session.
*/

import Foundation

struct NetworkGame: Hashable {
    var name: String
    var host: Player

    init(host: Player, name: String? = nil) {
        self.host = host
        self.name = name ?? "\(host.username)'s Game"
    }
}
