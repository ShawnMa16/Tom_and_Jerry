/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for finding network games.
*/

import UIKit
import os.log
import SnapKit

class NetworkGameBrowserViewController: UIViewController {

    let tableView: UITableView = {
        let table = UITableView()
        return table
    }()

    var session: NetworkSession?

    // must be set by parent
    var browser: GameBrowser? {
        didSet {
            oldValue?.stop()
        }
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.frame = CGRect(x: 0, y: 0, width: 300, height: 300)
        view.addSubview(tableView)
        tableView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().offset(0)
        }
        tableView.register(GameCell.self, forCellReuseIdentifier: "GameCell")
        
        tableView.dataSource = self
        tableView.delegate = self
        tableView.layer.cornerRadius = 10
        tableView.clipsToBounds = true
        startBrowser()
    }

    func startBrowser() {
        browser?.delegate = self
        browser?.start()
        tableView.reloadData()
    }

    func joinGame(_ game: NetworkGame) {
        guard let session = browser?.join(game: game) else {
            os_log(.error, "could not join game")
            return
        }
        guard let parent = parent as? GameStartViewController else { fatalError("unexpected parent") }
        parent.joinGame(session: session)
    }
    var games: [NetworkGame] = []
}

// MARK: - GameBrowserDelegate
extension NetworkGameBrowserViewController: GameBrowserDelegate {
    func gameBrowser(_ browser: GameBrowser, sawGames games: [NetworkGame]) {
        os_log(.info, "saw %d games!", games.count)
        
        if UserDefaults.standard.gameRoomMode {
//            self.games = games.filter { $0.location == location }
        } else {
            self.games = games
        }
        
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension NetworkGameBrowserViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "GameCell", for: indexPath)
        let game = games[indexPath.row]
        cell.textLabel?.text = game.name
        return cell
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return games.count
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}

// MARK: - UITableViewDelegate
extension NetworkGameBrowserViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let otherPlayer = games[indexPath.row]
        joinGame(otherPlayer)
    }
}
