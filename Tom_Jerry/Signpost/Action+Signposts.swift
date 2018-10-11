/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Performance debugging markers for GameAction.
*/

import Foundation

extension Action: CustomStringConvertible {
    var description: String {
        switch self {
        case .gameAction(let action):
            switch action {
            case .joyStickMoved:
                return "joy stick moved"
            case .movement(_):
                return "joy stick moved"
            }
        case .boardSetup(let setup):
            switch setup {
            case .requestBoardLocation:
                return "requestBoardLocation"
            case .boardLocation:
                return "boardLocation"
            }
        case .addTank:
            return "tank added"
        }
    }
}
