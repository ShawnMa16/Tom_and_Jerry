//
//  GameStartViewController.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 10/1/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import UIKit
import Foundation
import os.log
import SnapKit

protocol GameStartViewControllerDelegate: class {
    func gameStartViewController(_ gameStartViewController: UIViewController, didPressStartSoloGameButton: UIButton)
    func gameStartViewController(_ gameStartViewController: UIViewController, didStart game: NetworkSession)
    func gameStartViewController(_ gameStartViewController: UIViewController, didSelect game: NetworkSession)
}

class GameStartViewController: UIViewController {
    
    weak var delegate: GameStartViewControllerDelegate?
    var gameBrowser: GameBrowser?
    
    private let myself = UserDefaults.standard.myself
    
    let hostButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 78/255, green: 142/255, blue: 240/255, alpha: 1.0)
        button.setTitle("Host", for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        return button
    }()
    
    let joinButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 78/255, green: 142/255, blue: 240/255, alpha: 1.0)
        button.setTitle("Join", for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 12
        button.clipsToBounds = true
        return button
    }()
    
    var browserContainerView: UIView!
    let browserController = NetworkGameBrowserViewController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(hostButton)
        view.addSubview(joinButton)
        
        gameBrowser = GameBrowser(myself: myself)
        browserController.browser = gameBrowser
        self.addChild(browserController)
        
        browserContainerView = browserController.view
        view.addSubview(browserContainerView)
        browserContainerView.isHidden = true
        
        view.backgroundColor = .white
        setupButtons()
        setupBrowserView()
    }
    
    func setupButtons() {
        hostButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview().multipliedBy(0.5)
            make.bottom.equalToSuperview().offset(-50)
            make.width.equalTo(150)
            make.height.equalTo(50)
        }
        hostButton.addTarget(self, action: #selector(hostButtonPressed), for: .touchUpInside)
        
        joinButton.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview().multipliedBy(1.5)
            make.bottom.equalToSuperview().offset(-50)
            make.width.equalTo(150)
            make.height.equalTo(50)
        }
        joinButton.addTarget(self, action: #selector(joinButtonPressed), for: .touchUpInside)

    }
    
    func setupBrowserView() {        
        browserContainerView.snp.makeConstraints { (make) in
            make.width.height.equalTo(300)
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    
    func joinGame(session: NetworkSession) {
        delegate?.gameStartViewController(self, didSelect: session)
        setupOverlayVC()
    }
    
    func setupOverlayVC() {
        showViews(forSetup: true)
    }
    
    func showViews(forSetup: Bool) {
        UIView.transition(with: view, duration: 1.0, options: [.transitionCrossDissolve], animations: {
            self.joinButton.isHidden = !forSetup
            self.hostButton.isHidden = !forSetup
        }, completion: nil)
    }
    
    @objc func hostButtonPressed() {
        startGame(with: myself)
    }
    
    @objc func joinButtonPressed() {
        gameBrowser?.refresh()
        DispatchQueue.main.async {
            self.browserContainerView.isHidden = !self.browserContainerView.isHidden
        }
    }
    
    func startGame(with player: Player) {
        let gameSession = NetworkSession(myself: player, asServer: true, host: myself)
        delegate?.gameStartViewController(self, didStart: gameSession)
        setupOverlayVC()
    }
    
}
