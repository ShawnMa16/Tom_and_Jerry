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
            case .JoyStickInMoving:
                return "joy stick moved"
            case .JoyStickWillorStopMoving(_):
                return "shoud switch animation"
            }
        case .boardSetup(let setup):
            switch setup {
            case .requestBoardLocation:
                return "requestBoardLocation"
            case .boardLocation:
                return "boardLocation"
            }
        case .addObject:
            return "object added"
        }
    }
}
