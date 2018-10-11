//
//  GameCell.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 10/1/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import Foundation
import UIKit

class GameCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
