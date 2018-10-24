//
//  ViewController.swift
//  Tom_Jerry
//
//  Created by Shawn Ma on 9/22/18.
//  Copyright © 2018 Shawn Ma. All rights reserved.
//

import UIKit
import SnapKit
import ARKit
import SceneKit
import MultipeerConnectivity
import simd
import os.signpost

protocol GameViewControllerDelegate: class {
    func gameIsOver()
}

class GameViewController: UIViewController,  GameViewControllerDelegate{
    
    enum SessionState {
        case setup
        case lookingForSurface
        case adjustingBoard
        case placingBoard
        case waitingForBoard
        case localizingToBoard
        case setupLevel
        case gameInProgress
    }
    
    let arscnView: ARSCNView = {
        let view = ARSCNView()
        return view
    }()
    
    
    let gameStartViewContoller = GameStartViewController()
    var overlayView: UIView?
    
    // Root node of the level
    var renderRoot = SCNNode()
    
    // used when state is localizingToWorldMap or localizingToSavedMap
    var targetWorldMap: ARWorldMap?
    
    var focusSquare = FocusSquare()
    var screenCenter: CGPoint {
        let bounds = self.view.bounds
        return CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    lazy var padView: SKView = {
        let view = SKView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.isHidden = true
        return view
    }()
    
    let blackView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(displayP3Red: 0, green: 0, blue: 0, alpha: 0.6)
        view.isUserInteractionEnabled = false
        view.isHidden = true
        return view
    }()
    
    let wantMoreView: UITextView = {
        let view = UITextView()
        view.text = "Wanna know more?"
        view.textColor = .white
        view.font = .systemFont(ofSize: 100.0)
        view.backgroundColor = .clear
        view.textAlignment = .center
        view.isUserInteractionEnabled = false
        return view
    }()
    
    let contactInfoView: UITextView = {
        let view = UITextView()
        view.text = "xm596@nyu.edu \n nieyiyao@gmail.com"
        view.textColor = .white
        view.font = .systemFont(ofSize: 50.0)
        view.backgroundColor = .clear
        view.textAlignment = .center
        view.isUserInteractionEnabled = false
        return view
    }()
    
    let sessionInfoView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
        return view
    }()
    
    let sessionInfoLabel: UILabel = {
        let label = UILabel()
        label.adjustsFontSizeToFitWidth = true
        label.numberOfLines = 0
        label.textColor = .white
        return label
    }()
    
    lazy var addButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor(red: 78/255, green: 142/255, blue: 240/255, alpha: 1.0)
        button.setTitle("Add", for: .normal)
        button.tintColor = .white
        button.layer.cornerRadius = 5
        button.clipsToBounds = true
        button.isHidden = true
        return button
    }()
    
    lazy var mappingStatusLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        return label
    }()
    
    private let myself = UserDefaults.standard.myself
    
    var gameManager: GameManager? {
        didSet {
            guard let manager = gameManager else {
                sessionState = .setup
                return
            }
            
            if manager.isNetworked && !manager.isServer {
                sessionState = .waitingForBoard
            } else {
                sessionState = .lookingForSurface
            }
            manager.delegate = self
        }
    }
    
    var sessionState: SessionState = .setup
        
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(arscnView)
        view.addSubview(padView)
        view.addSubview(addButton)

        view.addSubview(blackView)
        blackView.addSubview(wantMoreView)
        blackView.addSubview(contactInfoView)
        
        view.addSubview(sessionInfoView)
        sessionInfoView.addSubview(sessionInfoLabel)
        sessionInfoView.addSubview(mappingStatusLabel)
        
        setupPadView()
        setupSubViews()
        setupPadScene()
        
        gameStartViewContoller.delegate = self
        
        overlayView = gameStartViewContoller.view
        
        renderRoot.name = "_renderRoot"
        arscnView.scene.rootNode.addChildNode(renderRoot)
        
        view.addSubview(overlayView!)
        view.bringSubviewToFront(overlayView!)
        
        // joystick moved
        NotificationCenter.default.addObserver(forName: joystickMoving, object: nil, queue: OperationQueue.main) { (notification) in
            guard let userInfo = notification.userInfo else { return }
            // get data from analogjoystick
            let data = userInfo["data"] as! AnalogJoystickData
            
            // format data for sending
            
            // object facing orientation
            let cameraDirection = self.arscnView.session.currentFrame?.camera.eulerAngles.y
            let angular = Float(data.angular) + cameraDirection!
            
            // roate the character's movement oreitation with camera's eulerAngles.y
            // x′= xcosθ − ysinθ
            // y′= ycosθ + xsinθ
            
            let velocity = float3(
                Float(data.velocity.x) * cos(cameraDirection!) - Float(data.velocity.y) * sin(cameraDirection!),
                Float(data.velocity.y) * cos(cameraDirection!) + Float(data.velocity.x) * sin(cameraDirection!), Float(0))
            let movement = GameVelocity(vector: velocity)
            let shouldBeSent = MoveData(velocity: movement, angular: angular)
            
            // controll tank's movement
            self.gameManager?.moveObject(player: self.myself, movement: shouldBeSent)
            
            // send movement data to all peer
            DispatchQueue.main.async {
                self.gameManager?.send(gameAction: .JoyStickInMoving(shouldBeSent))
            }
        }
        
        // begin moving
        NotificationCenter.default.addObserver(forName: joystickBeginMoving, object: nil, queue: OperationQueue.main) {
            (notification) in
            guard let data = notification.userInfo else {return}
            
            let isMoving = data["moving"] as! Bool
            print("========= begin moving ======== \(isMoving)")
            
            
            let shouldBeRunning = SwitchAnimation(isMoving: isMoving)
            DispatchQueue.main.async {
                self.gameManager?.switchAnimation(player: self.myself, isMoving: isMoving)
                self.gameManager?.send(gameAction: .JoyStickWillorStopMoving(shouldBeRunning))
            }
        }
        
        // end moving
        NotificationCenter.default.addObserver(forName: joystickEndMoving, object: nil, queue: OperationQueue.main) {
            (notification) in
            guard let data = notification.userInfo else {return}
            
            let isMoving = data["moving"] as! Bool
            print("========= end moving ========")
            
            
            let shouldBeRunning = SwitchAnimation(isMoving: isMoving)
            DispatchQueue.main.async {
                self.gameManager?.switchAnimation(player: self.myself, isMoving: isMoving)
                self.gameManager?.send(gameAction: .JoyStickWillorStopMoving(shouldBeRunning))
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        arscnView.session.pause()
    }
    
    func setupCamera() {
        guard let camera = arscnView.pointOfView?.camera else {
            fatalError("Expected a valid `pointOfView` from the scene.")
        }
        /*
         Enable HDR camera settings for the most realistic appearance
         with environmental lighting and physically based materials.
         */
        camera.wantsHDR = true
        camera.exposureOffset = -1
        camera.minimumExposure = -1
        camera.maximumExposure = 3
    }
    
    func setupARView() {
        arscnView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().offset(0)
        }
        
        arscnView.scene.rootNode.addChildNode(focusSquare)
    }
    
    func setupPadView() {
        padView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().offset(0)
        }
    }
    
    func setupPadScene() {
        let scene = ARJoystickSKScene(size: CGSize(width: view.bounds.size.width, height: 180))
        scene.scaleMode = .resizeFill
        padView.presentScene(scene)
        padView.ignoresSiblingOrder = true
    }
    
    func startARSession() {
        setupCamera()
        setupARView()
        initARScene()
        initARSession()
    }
    
    func initARScene() {
        arscnView.delegate = self
        arscnView.autoenablesDefaultLighting = false
        arscnView.automaticallyUpdatesLighting = false
    }
    
    func initARSession() {
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        arscnView.session.delegate = self
        
        // Start the view's AR session.
        resetTracking()
        // Prevent the screen from being dimmed after a while as users will likely
        // have long periods of interaction without touching the screen or buttons.
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    func resetTracking() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        if #available(iOS 12.0, *) {
            configuration.environmentTexturing = .automatic
        }
        arscnView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        arscnView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
    }
    
    func setupSubViews() {
        
        sessionInfoView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().offset(0)
        }
        
        sessionInfoLabel.snp.makeConstraints { (make) in
            make.top.left.equalToSuperview().offset(50)
        }
        
        mappingStatusLabel.snp.makeConstraints { (make) in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(addButton.snp.top).offset(-20)
        }
        
        addButton.snp.makeConstraints { (make) in
            make.left.equalToSuperview().offset(10)
            make.right.equalToSuperview().offset(-10)
            make.bottom.equalTo(arscnView.snp.bottom).offset(-50)
            make.height.equalTo(44)
        }

        
        blackView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().offset(0)
        }
        
        wantMoreView.snp.makeConstraints { (make) in
            make.width.equalTo(800)
            make.height.equalTo(220)
            make.top.equalToSuperview().offset(300)
            make.centerX.equalToSuperview()
        }
        
        contactInfoView.snp.makeConstraints { (make) in
            make.width.equalTo(500)
            make.height.equalTo(200)
            make.centerX.equalToSuperview()
            make.top.equalTo(self.wantMoreView.snp.bottom).offset(30)
        }
        
        
        addButton.isHidden = false
        addButton.addTarget(self, action: #selector(addObject), for: .touchUpInside)
        
    }
    
    
    @objc func addObject() {
        self.gameManager?.gameIsOverDelegate = self

        let addObject = AddObjectAction(simdWorldTransform: self.focusSquare.simdWorldTransform, eulerAngles: float3(0, self.focusSquare.eulerAngles.y + 180.0 * .pi / 180, 0), isAlive: true)
        
        // send add tank action to all peer
        self.gameManager?.send(addObjectAction: addObject)
        // add tank to scene
        DispatchQueue.main.async {
            self.addButton.isHidden = true
            self.padView.isHidden = false
            self.focusSquare.isHidden = true
            
            self.gameManager?.createObject(addNodeAction: addObject, owner: self.myself)
        }
        
    }
    
    
    // MARK:- game logic
    
    @objc func startGame() {
        let gameSession = NetworkSession(myself: myself, asServer: true, host: myself)
        self.gameManager = GameManager(sceneView: self.arscnView, session: gameSession)
    }
    
    func showAlert(title: String, message: String? = nil, actions: [UIAlertAction]? = nil) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if let actions = actions {
            actions.forEach { alertController.addAction($0) }
        } else {
            alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        }
        present(alertController, animated: true, completion: nil)
    }
    
    private func process(boardAction: BoardSetupAction, from peer: Player) {
        switch boardAction {
        case .boardLocation(let location):
            switch location {
            case .worldMapData(let data):
                os_log(.info, "Received WorldMap data. Size: %d", data.count)
                loadWorldMap(from: data)
            case .manual:
                os_log(.info, "Received a manual board placement")
                sessionState = .lookingForSurface
            }
        case .requestBoardLocation:
            sendWorldTo(peer: peer)
        }
    }
    
    func sendWorldTo(peer: Player) {
        guard let gameManager = gameManager, gameManager.isServer else { os_log(.error, "i'm not the server"); return }
        
        switch UserDefaults.standard.boardLocatingMode {
        case .worldMap:
            os_log(.info, "generating worldmap for %s", "\(peer)")
            getCurrentWorldMapData { data, error in
                if let error = error {
                    os_log(.error, "didn't work! %s", "\(error)")
                    return
                }
                guard let data = data else { os_log(.error, "no data!"); return }
                os_log(.info, "got a compressed map, sending to %s", "\(peer)")
                let location = GameBoardLocation.worldMapData(data)
                DispatchQueue.main.async {
                    os_log(.info, "sending worldmap to %s", "\(peer)")
                    gameManager.send(boardAction: .boardLocation(location), to: peer)
                }
            }
        case .manual:
            gameManager.send(boardAction: .boardLocation(.manual), to: peer)
        }
    }
    
    func loadWorldMap(from archivedData: Data) {
        do {
            let uncompressedData = try archivedData.decompressed()
            guard let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: uncompressedData) else {
                os_log(.error, "The WorldMap received couldn't be read")
                DispatchQueue.main.async {
                    self.showAlert(title: "An error occured while loading the WorldMap (Failed to read)")
                    self.sessionState = .setup
                }
                return
            }
            
            DispatchQueue.main.async {
                self.targetWorldMap = worldMap
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                
                self.arscnView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                
                self.sessionState = .localizingToBoard
            }
        } catch {
            os_log(.error, "The WorldMap received couldn't be decompressed")
            DispatchQueue.main.async {
                self.showAlert(title: "An error occured while loading the WorldMap (Failed to decompress)")
                self.sessionState = .setup
            }
        }
    }
    
    func getCurrentWorldMapData(_ closure: @escaping (Data?, Error?) -> Void) {
        os_log(.info, "in getCurrentWordMapData")
        // When loading a map, send the loaded map and not the current extended map
        if let targetWorldMap = targetWorldMap {
            os_log(.info, "using existing worldmap, not asking session for a new one.")
            compressMap(map: targetWorldMap, closure)
            return
        } else {
            os_log(.info, "asking ARSession for the world map")
            arscnView.session.getCurrentWorldMap { map, error in
                os_log(.info, "ARSession getCurrentWorldMap returned")
                if let error = error {
                    os_log(.error, "didn't work! %s", "\(error)")
                    closure(nil, error)
                }
                guard let map = map else { os_log(.error, "no map either!"); return }
                os_log(.info, "got a worldmap, compressing it")
                self.compressMap(map: map, closure)
            }
        }
    }
    
    private func compressMap(map: ARWorldMap, _ closure: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                os_log(.info, "data size is %d", data.count)
                let compressedData = data.compressed()
                os_log(.info, "compressed size is %d", compressedData.count)
                closure(compressedData, nil)
            } catch {
                os_log(.error, "archiving failed %s", "\(error)")
                closure(nil, error)
            }
        }
    }
    
    
    func hideOverlay() {
        UIView.transition(with: view, duration: 1.0, options: [.transitionCrossDissolve], animations: {
            self.overlayView!.isHidden = true
        }) { _ in
            self.overlayView!.isUserInteractionEnabled = false
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    func gameIsOver() {
        DispatchQueue.main.async {            
            UIView.animate(withDuration: 0.3, delay: 0, options: .transitionCrossDissolve, animations: {
                self.blackView.isHidden = false
            }, completion: nil)
        }
    }

}

extension GameViewController: GameManagerDelegate {
    func manager(_ manager: GameManager, addTank: AddObjectAction) {
        //
    }
    
    func manager(_ manager: GameManager, received boardAction: BoardSetupAction, from player: Player) {
        DispatchQueue.main.async {
            self.process(boardAction: boardAction, from: player)
        }
    }
    
    func manager(_ manager: GameManager, joiningPlayer player: Player) {
        //
    }
    
    func manager(_ manager: GameManager, leavingPlayer player: Player) {
        //
    }
    
    func manager(_ manager: GameManager, joiningHost host: Player) {
        // MARK: request worldmap when joining the host
        DispatchQueue.main.async {
            if self.sessionState == .waitingForBoard {
                manager.send(boardAction: .requestBoardLocation)
            }
            guard !UserDefaults.standard.disableInGameUI else { return }
        }
    }
    
    func manager(_ manager: GameManager, leavingHost host: Player) {
        //
    }
    
    func managerDidStartGame(_ manager: GameManager) {
        //
    }
    
    
}

extension GameViewController: GameStartViewControllerDelegate {
    private func createGameManager(for session: NetworkSession?) {
        gameManager = GameManager(sceneView: arscnView,
                                  session: session)
        gameManager?.startGame()
        startARSession()
    }
    
    func gameStartViewController(_ _: UIViewController, didPressStartSoloGameButton: UIButton) {
        hideOverlay()
        createGameManager(for: nil)
    }
    
    func gameStartViewController(_ _: UIViewController, didStart game: NetworkSession) {
        hideOverlay()
        createGameManager(for: game)
    }
    
    func gameStartViewController(_ _: UIViewController, didSelect game: NetworkSession) {
        hideOverlay()
        createGameManager(for: game)
    }
}

