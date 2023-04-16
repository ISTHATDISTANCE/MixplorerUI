import ARKit
import SwiftUI
import Foundation
import SceneKit
import UIKit
import Photos

import Firebase
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage

class MainViewController: UIViewController {
    var dragOnInfinitePlanesEnabled = false
    var currentGesture: Gesture?
    
    var use3DOFTrackingFallback = false
    var screenCenter: CGPoint?
    
    let session = ARSession()
    var sessionConfig: ARConfiguration = ARWorldTrackingConfiguration()
    
    
    var trackingFallbackTimer: Timer?
    
    // Use average of recent virtual object distances to avoid rapid changes in object scale.
    var recentVirtualObjectDistances = [CGFloat]()
    
    let DEFAULT_DISTANCE_CAMERA_TO_OBJECTS = Float(10)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Setting.registerDefaults()
        setupScene()
        setupDebug()
        setupUIControls()
        setupFocusSquare()
        updateSettings()
        resetVirtualObject()
        
//        screenshotButton.isHidden = true
        
//        listenSuggestionsFromFirebase()
        listenSuggestionsFromFirebaseMultipleObjects()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
        restartPlaneDetection()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.pause()
    }
    
    func listenSuggestionsFromFirebaseMultipleObjects(){
        let ref = Database.database().reference()
        
        let objects = ["vase", "lamp", "chair"]
        for object in objects {
            ref.child(object).observe(.value) { snapshot in
                guard let suggestions = snapshot.value as? NSArray else {
                    print("something wrong", snapshot.value)
                    return
                }
                print("New suggestions: \(suggestions)")
                
                for virtualObject in VirtualObjectsManager.shared.getVirtualObjects(){
                    if object == virtualObject.modelName{
                        
                        if virtualObject.isHidden {
                            virtualObject.isHidden = false
                        }
                        
                        var doubleArray = [Double]()
                        for element in suggestions {
                            if let str = element as? String, let doubleValue = Double(str) {
                                doubleArray.append(doubleValue)
                            } else if let num = element as? NSNumber {
                                doubleArray.append(num.doubleValue)
                            }
                        }
                        let width = self.sceneView.bounds.width
                        let height = self.sceneView.bounds.height
                        let point = CGPoint(x: (doubleArray[0] ) * width, y: (doubleArray[1] ) * height)
                        VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: virtualObject)
                        
                        virtualObject.translateBasedOnScreenPos(point, instantly:true, infinitePlane:false)
                    }
                    
                }
                
            }
        }
        self.textManager.showMessage("AI suggestions received")

    }
    
    
    func listenSuggestionsFromFirebase(){
        print("observing suggestions")
        let ref = Database.database().reference()
        ref.child("Suggestions").observe(.value) { snapshot in
            guard let suggestions = snapshot.value as? NSArray else {
                print("something wrong", snapshot.value)
                return
            }
            print("New suggestions: \(suggestions)")
            self.adjustObjectBasedOnAI(suggestions: suggestions)
        }
    }
    
    func addObjectBasedOnAI(suggestions: NSArray) {} // DEPRECATED: now AI suggestion only applies to currently selected object
    func adjustObjectBasedOnAI(suggestions: NSArray){
        var doubleArray = [Double]()
        for element in suggestions {
            if let str = element as? String, let doubleValue = Double(str) {
                doubleArray.append(doubleValue)
            } else if let num = element as? NSNumber {
                doubleArray.append(num.doubleValue)
            }
        }
                
        DispatchQueue.main.async {
            let width = 400.0
            let height = 720.0
            let point = CGPoint(x: (doubleArray[0] ) * width, y: (doubleArray[1] ) * height)
            VirtualObjectsManager.shared.getVirtualObjectSelected()?.translateBasedOnScreenPos(point, instantly:true, infinitePlane:false)
        }
    }
    
    
    // MARK: - ARKit / ARSCNView
    var use3DOFTracking = false {
        didSet {
            if use3DOFTracking {
                sessionConfig = ARWorldTrackingConfiguration()
            }
            sessionConfig.isLightEstimationEnabled = UserDefaults.standard.bool(for: .ambientLightEstimation)
            session.run(sessionConfig)
        }
    }
    @IBOutlet var sceneView: ARSCNView!
    
    // MARK: - Ambient Light Estimation
    func toggleAmbientLightEstimation(_ enabled: Bool) {
        if enabled {
            if !sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = true
                session.run(sessionConfig)
            }
        } else {
            if sessionConfig.isLightEstimationEnabled {
                sessionConfig.isLightEstimationEnabled = false
                session.run(sessionConfig)
            }
        }
    }
    
    // MARK: - Virtual Object Loading
    var isLoadingObject: Bool = false {
        didSet {
            DispatchQueue.main.async {
                //				self.settingsButton.isEnabled = !self.isLoadingObject
                self.addObjectButton.isEnabled = !self.isLoadingObject
                self.screenshotButton.isEnabled = !self.isLoadingObject
                self.restartExperienceButton.isEnabled = !self.isLoadingObject
            }
        }
    }
    
    @IBOutlet weak var randomizeButton: UIButton!
    
    @IBAction func randomizeObjects(_ button: UIButton) {
        let width = self.sceneView.bounds.width
        let height = self.sceneView.bounds.height
        let point = CGPoint(x: Float64.random(in: 0...width), y: Float64.random(in: 0.2*height...height))
        DispatchQueue.main.async {
              VirtualObjectsManager.shared.getVirtualObjectSelected()?.translateBasedOnScreenPos(point, instantly:true, infinitePlane:false)
        }
    }
    @IBOutlet weak var addObjectButton: UIButton!
    
    @IBAction func chooseObject(_ button: UIButton) {
        // Abort if we are about to load another object to avoid concurrent modifications of the scene.
        if isLoadingObject { return }
        textManager.cancelScheduledMessage(forType: .contentPlacement)
        
        let rowHeight = 45
        let popoverSize = CGSize(width: 250, height: rowHeight * VirtualObjectSelectionViewController.COUNT_OBJECTS)
        
        //        print("UIbotton", button)
        //        print("COUNT_OBJECTS", VirtualObjectSelectionViewController.COUNT_OBJECTS)
        
        let objectViewController = VirtualObjectSelectionViewController(size: popoverSize)
        objectViewController.delegate = self
        objectViewController.modalPresentationStyle = .popover
        objectViewController.popoverPresentationController?.delegate = self
        self.present(objectViewController, animated: true, completion: nil)
        
        objectViewController.popoverPresentationController?.sourceView = button
        objectViewController.popoverPresentationController?.sourceRect = button.bounds
    }
    
    // MARK: - Planes
    
    var planes = [ARPlaneAnchor: Plane]()
    
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let pos = SCNVector3.positionFromTransform(anchor.transform)
        textManager.showDebugMessage("New Surface Detected at \(pos.friendlyString())")
        
        let plane = Plane(anchor, showDebugVisuals)
        
        planes[anchor] = plane
        node.addChildNode(plane)
        
        textManager.cancelScheduledMessage(forType: .planeEstimation)
        textManager.showMessage("Surface detected")
        if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
            textManager.scheduleMessage("Tap + to place an object", inSeconds: 7.5, messageType: .contentPlacement)
        }
    }
    
    func restartPlaneDetection() {
        // configure session
        if let worldSessionConfig = sessionConfig as? ARWorldTrackingConfiguration {
            worldSessionConfig.planeDetection = .horizontal
            session.run(worldSessionConfig, options: [.resetTracking, .removeExistingAnchors])
        }
        
        // reset timer
        if trackingFallbackTimer != nil {
            trackingFallbackTimer!.invalidate()
            trackingFallbackTimer = nil
        }
        
        //		textManager.scheduleMessage("FIND A SURFACE TO PLACE AN OBJECT", inSeconds: 7.5, messageType: .planeEstimation)
    }
    
    // MARK: - Focus Square
    var focusSquare: FocusSquare?
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
        sceneView.scene.rootNode.addChildNode(focusSquare!)
        
        textManager.scheduleMessage("Try Moving Left or Right", inSeconds: 5.0, messageType: .focusSquare)
    }
    
    func updateFocusSquare() {
        guard let screenCenter = screenCenter else { return }
        
        let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
        if virtualObject != nil && sceneView.isNode(virtualObject!, insideFrustumOf: sceneView.pointOfView!) {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = worldPositionFromScreenPosition(screenCenter, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: self.session.currentFrame?.camera)
            textManager.cancelScheduledMessage(forType: .focusSquare)
        }
    }
    
    // MARK: - Hit Test Visualization
    
    var hitTestVisualization: HitTestVisualization?
    
    var showHitTestAPIVisualization = UserDefaults.standard.bool(for: .showHitTestAPI) {
        didSet {
            UserDefaults.standard.set(showHitTestAPIVisualization, for: .showHitTestAPI)
            if showHitTestAPIVisualization {
                hitTestVisualization = HitTestVisualization(sceneView: sceneView)
            } else {
                hitTestVisualization = nil
            }
        }
    }
    
    // MARK: - Debug Visualizations
    
    //	@IBOutlet var featurePointCountLabel: UILabel!
    
    func refreshFeaturePoints() {
        guard showDebugVisuals else {
            return
        }
        
        guard let cloud = session.currentFrame?.rawFeaturePoints else {
            return
        }
        
        DispatchQueue.main.async {
            //			self.featurePointCountLabel.text = "Features: \(cloud.__count)".uppercased()
        }
    }
    
    var showDebugVisuals: Bool = UserDefaults.standard.bool(for: .debugMode) {
        didSet {
            //			featurePointCountLabel.isHidden = !showDebugVisuals
//            debugMessageLabel.isHidden = !showDebugVisuals
            //			messagePanel.isHidden = !showDebugVisuals
            planes.values.forEach { $0.showDebugVisualization(showDebugVisuals) }
            sceneView.debugOptions = []
            if showDebugVisuals {
                sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints, ARSCNDebugOptions.showWorldOrigin]
            }
            UserDefaults.standard.set(showDebugVisuals, for: .debugMode)
        }
    }
    
    func setupDebug() {
        //		messagePanel.layer.cornerRadius = 3.0
        //		messagePanel.clipsToBounds = true
        return
    }
    
    // MARK: - UI Elements and Actions
    
    //	@IBOutlet weak var messagePanel: UIView!
    @IBOutlet weak var messageLabel: UILabel!
    //	@IBOutlet weak var debugMessageLabel: UILabel!
    
    var textManager: TextManager!
    
    func setupUIControls() {
        textManager = TextManager(viewController: self)
//        debugMessageLabel.isHidden = true
//        featurePointCountLabel.text = ""
//        debugMessageLabel.text = ""
        messageLabel.text = ""
    }
    
    @IBOutlet weak var restartExperienceButton: UIButton!
    var restartExperienceButtonIsEnabled = true
    
    @IBAction func restartExperience(_ sender: Any) {
        print("test")
        guard restartExperienceButtonIsEnabled, !isLoadingObject else {
            return
        }
        print("restart")
        textManager.showMessage("Virtual objects Cleared")
        DispatchQueue.main.async {
            self.restartExperienceButtonIsEnabled = false
            
            self.textManager.cancelAllScheduledMessages()
            self.textManager.dismissPresentedAlert()
            self.textManager.showMessage("Starting a new session...")
            self.use3DOFTracking = false
            
            self.setupFocusSquare()
            //			self.loadVirtualObject()
            self.restartPlaneDetection()
            
            self.restartExperienceButton.setImage(#imageLiteral(resourceName: "restart"), for: [])
            self.resetVirtualObject()
            // Disable Restart button for five seconds in order to give the session enough time to restart.
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: {
                self.restartExperienceButtonIsEnabled = true
            })
        }
    }
    
    
    func sendImageToFireBase(){
        guard sceneView.session.currentFrame != nil else { return }
        // Convert the snapshot image to a Data object
        sceneView.scene.background.contents = UIColor.clear

        guard let snapshotData = sceneView.snapshot().pngData() else {
            // handle error
            return
        }
        
        let storageRef = Storage.storage().reference().child("images/snapshots.png")
        
        print("uploading snapShot")
        storageRef.putData(snapshotData, metadata: nil) { metadata, error in
            if let error = error {
                // handle error
                print("Error uploading snapshot: \(error.localizedDescription)")
                return
            }
            
            // The snapshot has been successfully uploaded to Firebase Storage
            print("Snapshot uploaded to Firebase Storage")
        }
        print("Complete snapShot")
        
        print("updating Realtime DB")
        let now = Date().timeIntervalSince1970
        let beginningOfWorld = Date(timeIntervalSince1970: 0).timeIntervalSince1970
        let worldLifetime = now - beginningOfWorld
        let RTDB = Database.database().reference()
        RTDB.child("Update").setValue(worldLifetime)
        print("complete Realtime DB")
        
        
        ///upload raw image
        
        guard let currentFrame = self.session.currentFrame else { return }
        let capturedImage = currentFrame.capturedImage
        
        let ciImage = CIImage(cvPixelBuffer: capturedImage)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let uiImage = UIImage(cgImage: cgImage)
        
        let rawRef = Storage.storage().reference().child("images/raw.png")
        
        print("uploading raw")
        if let imageData = uiImage.pngData(){
            rawRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    // handle error
                    print("Error uploading snapshot: \(error.localizedDescription)")
                    return
                }
                
                print("Raw uploaded to Firebase Storage")
            }
            print("Complete RawImage")
        }
        
        
    }
    
    @IBOutlet weak var posButton: UIButton!
    @IBAction func positiveUpload(){
        textManager.showMessage("Image labeled positive")
        print("positiveUpload")
        determineNegPos(NegPosSet:"pos")
    }
    
    @IBOutlet weak var negButton: UIButton!
    @IBAction func negativeUpload(){
        textManager.showMessage("Image labeled negative")
        determineNegPos(NegPosSet:"neg")
    }
    
    func determineNegPos(NegPosSet:String){
        guard sceneView.session.currentFrame != nil else { return }
        guard let snapshotData = sceneView.snapshot().pngData() else { return }
        let identifier = UUID()
        let arFileName = "ar/" + identifier.uuidString + ".png"
        let storageRef = Storage.storage().reference().child(arFileName)
        storageRef.putData(snapshotData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading snapshot: \(error.localizedDescription)")
                return
            }
            print("Snapshot uploaded to Firebase Storage")
        }

        ///upload raw image
        guard let currentFrame = self.session.currentFrame else { return }
        let capturedImage = currentFrame.capturedImage

        let ciImage = CIImage(cvPixelBuffer: capturedImage)
        let context = CIContext(options: nil)
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)!
        let uiImage = UIImage(cgImage: cgImage)

        let rawFileName = "raw/" + identifier.uuidString + ".png"
        let rawRef = Storage.storage().reference().child(rawFileName)
        if let imageData = uiImage.pngData(){
            rawRef.putData(imageData, metadata: nil) { metadata, error in
                if let error = error {
                    print("Error uploading snapshot: \(error.localizedDescription)")
                    return
                }
                print("Raw uploaded to Firebase Storage")
            }
            print("Complete RawImage")
        }
        
        
        guard let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected() else { return }
        let BBox = getBoundingBoxRectForVirtualObject(on:sceneView, node: virtualObject)
        print(BBox)
//        let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
//        guard let virtualObjectPosition = virtualObject?.worldPosition else { return }
//        let screenCoordinate = sceneView.projectPoint(virtualObjectPosition)
//        let scalingFactor = UIScreen.main.scale
//        let pointCoordinate = CGPoint(x: CGFloat(screenCoordinate.x) * scalingFactor, y: CGFloat(screenCoordinate.y) * scalingFactor)
//        print(pointCoordinate)

//        let now = Date().timeIntervalSince1970
//        let worldLifetime = now - Date(timeIntervalSince1970: 0).timeIntervalSince1970
        let RTDB = Database.database().reference(withPath: "log")
        
        var logs = ["positive" : 1, "negative" : 0]
        if (NegPosSet == "neg"){
            logs = ["positive" : 0, "negative" : 1]
        }
        RTDB.child(identifier.uuidString).setValue(logs)
    }
    
    
    func getBoundingBoxRectForVirtualObject(on arView: ARSCNView, node virtualObjectNode: SCNNode) -> CGRect {
        let boundingBox = virtualObjectNode.boundingBox
        let corners = [
            SCNVector3(boundingBox.min.x, boundingBox.min.y, boundingBox.min.z),
            SCNVector3(boundingBox.min.x, boundingBox.min.y, boundingBox.max.z),
            SCNVector3(boundingBox.min.x, boundingBox.max.y, boundingBox.min.z),
            SCNVector3(boundingBox.min.x, boundingBox.max.y, boundingBox.max.z),
            SCNVector3(boundingBox.max.x, boundingBox.min.y, boundingBox.min.z),
            SCNVector3(boundingBox.max.x, boundingBox.min.y, boundingBox.max.z),
            SCNVector3(boundingBox.max.x, boundingBox.max.y, boundingBox.min.z),
            SCNVector3(boundingBox.max.x, boundingBox.max.y, boundingBox.max.z),
        ]
        let count = corners.count
        let pointer = UnsafeMutablePointer<SCNVector3>.allocate(capacity: count)
        pointer.initialize(from: corners, count: count)
        let camera = arView.session.currentFrame?.camera
        let viewportSize = arView.bounds.size
//        let orientation: CGImagePropertyOrientation = {
//            let deviceOrientation = UIDevice.current.orientation
//            switch deviceOrientation {
//            case .portrait: return .right
//            case .portraitUpsideDown: return .left
//            case .landscapeLeft: return .up
//            case .landscapeRight: return .down
//            default: return .right
//            }
//        }()
        let projectedPoints = Array(UnsafeBufferPointer(start: pointer, count: count)).map { point -> CGPoint in
            
            let screenCoordinate = arView.projectPoint(point)
            let scalingFactor = UIScreen.main.scale
            let pointCoordinate = CGPoint(x: CGFloat(screenCoordinate.x) * scalingFactor, y: CGFloat(screenCoordinate.y) * scalingFactor)
            return pointCoordinate
//            let pointInImage = camera?.project(point, orientation: orientation, viewportSize: viewportSize)
//            let pointOnScreen = arView.convertToViewport(pointInImage!, orientation: orientation)
//            return CGPoint(x: CGFloat(pointOnScreen.x), y: CGFloat(pointOnScreen.y))
        }
        var boundingBox2D = CGRect.null
        for i in 0..<count {
            let point = projectedPoints[i]
            boundingBox2D = boundingBox2D.union(CGRect(origin: point, size: .zero))
        }
        let scalingFactor = UIScreen.main.scale
        let boundingBoxPoints = [
            CGPoint(x: boundingBox2D.minX * scalingFactor, y: boundingBox2D.minY * scalingFactor),
            CGPoint(x: boundingBox2D.maxX * scalingFactor, y: boundingBox2D.minY * scalingFactor),
            CGPoint(x: boundingBox2D.maxX * scalingFactor, y: boundingBox2D.maxY * scalingFactor),
            CGPoint(x: boundingBox2D.minX * scalingFactor, y: boundingBox2D.maxY * scalingFactor),
        ]
        let boundingBoxPath = UIBezierPath()
            boundingBoxPath.move(to: boundingBoxPoints[0])
            boundingBoxPath.addLine(to: boundingBoxPoints[1])
            boundingBoxPath.addLine(to: boundingBoxPoints[2])
            boundingBoxPath.addLine(to: boundingBoxPoints[3])
            boundingBoxPath.close()
            let boundingBoxRect = boundingBoxPath.cgPath.boundingBox
            return boundingBoxRect
    }



    
    @IBOutlet weak var autoButton: UIButton!
    @IBAction func autoGeneration(){
        print("autoButton is clicked")
        textManager.showMessage("AI suggestions requested")
        let virtualObject = VirtualObjectsManager.shared.getVirtualObjectSelected()
        let worldLifetime = Date().timeIntervalSince1970 - Date(timeIntervalSince1970: 0).timeIntervalSince1970
        guard let modelName = virtualObject?.modelName else { return }
        let RTDB = Database.database().reference()
        RTDB.child(modelName).setValue(worldLifetime)
        
        guard let snapshotData = sceneView.snapshot().pngData() else { return}
        
        let storageRef = Storage.storage().reference().child("images/updateRaw.png")
        
        storageRef.putData(snapshotData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading snapshot: \(error.localizedDescription)")
                return
            }
            print("Snapshot uploaded to Firebase Storage")
        }
        adjustObjectBasedOnAI(suggestions: NSArray(array:[Float(0),Float(0)])) // TODO: delete me!!!!
    }
    @IBOutlet weak var shuffleButton: UIButton!
    @IBAction func shuffle(){
        textManager.showMessage("Random shuffled")
        for virtualObject in VirtualObjectsManager.shared.getVirtualObjects() {
            let worldLifetime = Date().timeIntervalSince1970 - Date(timeIntervalSince1970: 0).timeIntervalSince1970
            let modelName = virtualObject.modelName
            let RTDB = Database.database().reference()
            RTDB.child(modelName).setValue(worldLifetime)
        }
        
        for virtualObject in VirtualObjectsManager.shared.getVirtualObjects() {
            virtualObject.isHidden = true
        }
        guard let snapshotData = sceneView.snapshot().pngData() else { return}
        let storageRef = Storage.storage().reference().child("images/updateRaw.png")
        storageRef.putData(snapshotData, metadata: nil) { metadata, error in
            if let error = error {
                print("Error uploading snapshot: \(error.localizedDescription)")
                return
            }
            print("Snapshot uploaded to Firebase Storage")
        }
    }
    
	@IBOutlet weak var screenshotButton: UIButton!
	@IBAction func takeSnapShot() {
        textManager.showMessage("Snapshot taken & sent to Firebase")
		guard sceneView.session.currentFrame != nil else { return }
//		focusSquare?.isHidden = true
        
        let snapShot = sceneView.snapshot()
        sendImageToFireBase()
        
        UIImageWriteToSavedPhotosAlbum(snapShot, self, #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
//		let imagePlane = SCNPlane(width: sceneView.bounds.width / 6000, height: sceneView.bounds.height / 6000)
//		imagePlane.firstMaterial?.diffuse.contents = sceneView.snapshot()
//		imagePlane.firstMaterial?.lightingModel = .constant
//
//		let planeNode = SCNNode(geometry: imagePlane)
//		sceneView.scene.rootNode.addChildNode(planeNode)
//
//		focusSquare?.isHidden = false
	}
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {

        if let error = error {
            print("Error Saving ARKit Scene \(error)")
        } else {
            print("ARKit Scene Successfully Saved")
        }
    }
	// MARK: - Settings

//	@IBOutlet weak var settingsButton: UIButton!

	@IBAction func showSettings(_ button: UIButton) {
		let storyboard = UIStoryboard(name: "Main", bundle: nil)
		guard let settingsViewController = storyboard.instantiateViewController(
			withIdentifier: "settingsViewController") as? SettingsViewController else {
			return
		}

		let barButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(dismissSettings))
		settingsViewController.navigationItem.rightBarButtonItem = barButtonItem
		settingsViewController.title = "Options"

		let navigationController = UINavigationController(rootViewController: settingsViewController)
		navigationController.modalPresentationStyle = .popover
		navigationController.popoverPresentationController?.delegate = self
		navigationController.preferredContentSize = CGSize(width: sceneView.bounds.size.width - 20,
		                                                   height: sceneView.bounds.size.height - 50)
		self.present(navigationController, animated: true, completion: nil)

//		navigationController.popoverPresentationController?.sourceView = settingsButton
//		navigationController.popoverPresentationController?.sourceRect = settingsButton.bounds
	}

    @objc
    func dismissSettings() {
		self.dismiss(animated: true, completion: nil)
		updateSettings()
	}

	private func updateSettings() {
		let defaults = UserDefaults.standard

		showDebugVisuals = defaults.bool(for: .debugMode)
		toggleAmbientLightEstimation(defaults.bool(for: .ambientLightEstimation))
		dragOnInfinitePlanesEnabled = defaults.bool(for: .dragOnInfinitePlanes)
		showHitTestAPIVisualization = defaults.bool(for: .showHitTestAPI)
		use3DOFTracking	= defaults.bool(for: .use3DOFTracking)
		use3DOFTrackingFallback = defaults.bool(for: .use3DOFFallback)
		for (_, plane) in planes {
			plane.updateOcclusionSetting()
		}
	}

	// MARK: - Error handling

	func displayErrorMessage(title: String, message: String, allowRestart: Bool = false) {
		textManager.blurBackground()

		if allowRestart {
			let restartAction = UIAlertAction(title: "Reset", style: .default) { _ in
				self.textManager.unblurBackground()
				self.restartExperience(self)
			}
			textManager.showAlert(title: title, message: message, actions: [restartAction])
		} else {
			textManager.showAlert(title: title, message: message, actions: [])
		}
	}
}

extension ARSCNView {
    /// Performs screen snapshot manually, seems faster than built in snapshot() function, but still somewhat noticeable
    var snapshot: UIImage? {
       let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        let image = renderer.image(actions: { context in
            self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
        })
        return image
    }
}

// MARK: - ARKit / ARSCNView
extension MainViewController {
	func setupScene() {
		sceneView.setUp(viewController: self, session: session)
		DispatchQueue.main.async {
			self.screenCenter = self.sceneView.bounds.mid
		}
	}
    

	func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
		textManager.showTrackingQualityInfo(for: camera.trackingState, autoHide: !self.showDebugVisuals)
        
		switch camera.trackingState {
		case .notAvailable:
            break
			textManager.escalateFeedback(for: camera.trackingState, inSeconds: 5.0)
		case .limited:
			if use3DOFTrackingFallback {
				// After 10 seconds of limited quality, fall back to 3DOF mode.
				trackingFallbackTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { _ in
					self.use3DOFTracking = true
					self.trackingFallbackTimer?.invalidate()
					self.trackingFallbackTimer = nil
				})
			} else {
				textManager.escalateFeedback(for: camera.trackingState, inSeconds: 10.0)
			}
		case .normal:
			textManager.cancelScheduledMessage(forType: .trackingStateEscalation)
			if use3DOFTrackingFallback && trackingFallbackTimer != nil {
				trackingFallbackTimer!.invalidate()
				trackingFallbackTimer = nil
			}
		}
	}

	func session(_ session: ARSession, didFailWithError error: Error) {
		guard let arError = error as? ARError else { return }

		let nsError = error as NSError
		var sessionErrorMsg = "\(nsError.localizedDescription) \(nsError.localizedFailureReason ?? "")"
		if let recoveryOptions = nsError.localizedRecoveryOptions {
			for option in recoveryOptions {
				sessionErrorMsg.append("\(option).")
			}
		}

		let isRecoverable = (arError.code == .worldTrackingFailed)
		if isRecoverable {
			sessionErrorMsg += "\nYou can try resetting the session or quit the application."
		} else {
			sessionErrorMsg += "\nThis is an unrecoverable error that requires to quit the application."
		}

		displayErrorMessage(title: "We're sorry!", message: sessionErrorMsg, allowRestart: isRecoverable)
	}

	func sessionWasInterrupted(_ session: ARSession) {
		textManager.blurBackground()
		textManager.showAlert(title: "Session Interrupted",
		                      message: "The session will be reset after the interruption has ended.")
	}

	func sessionInterruptionEnded(_ session: ARSession) {
		textManager.unblurBackground()
		session.run(sessionConfig, options: [.resetTracking, .removeExistingAnchors])
		restartExperience(self)
		textManager.showMessage("Resetting session")
	}
}

// MARK: Gesture Recognized
extension MainViewController {
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
			return
		}

		if currentGesture == nil {
			currentGesture = Gesture.startGestureFromTouches(touches, self.sceneView, object)
		} else {
			currentGesture = currentGesture!.updateGestureFromTouches(touches, .touchBegan)
		}

		displayVirtualObjectTransform()
	}

	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchMoved)
		displayVirtualObjectTransform()
	}

	override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			chooseObject(addObjectButton)
			return
		}

		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchEnded)
	}

	override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
		if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
			return
		}
		currentGesture = currentGesture?.updateGestureFromTouches(touches, .touchCancelled)
	}
}

// MARK: - UIPopoverPresentationControllerDelegate
extension MainViewController: UIPopoverPresentationControllerDelegate {
	func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
		return .none
	}

	func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
		updateSettings()
	}
}

// MARK: - VirtualObjectSelectionViewControllerDelegate
extension MainViewController: VirtualObjectSelectionViewControllerDelegate {
	func virtualObjectSelectionViewController(_: VirtualObjectSelectionViewController, object: VirtualObject) {
        print("loadVirtualObject", object)
        loadVirtualObject(object: object)
	}
    

	func loadVirtualObject(object: VirtualObject) {
		// Show progress indicator
		let spinner = UIActivityIndicatorView()
		spinner.center = addObjectButton.center
		spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
		addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
		sceneView.addSubview(spinner)
		spinner.startAnimating()
        
        print("loadVirtualObject")

		DispatchQueue.global().async {
			self.isLoadingObject = true
			object.viewController = self
			VirtualObjectsManager.shared.addVirtualObject(virtualObject: object)
			VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: object)

			object.loadModel()
			DispatchQueue.main.async {
				if let lastFocusSquarePos = self.focusSquare?.lastPosition {
					self.setNewVirtualObjectPosition(lastFocusSquarePos)
				} else {
					self.setNewVirtualObjectPosition(SCNVector3Zero)
				}

				spinner.removeFromSuperview()

				// Update the icon of the add object button
				let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
				let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
				self.addObjectButton.setImage(buttonImage, for: [])
				self.addObjectButton.setImage(pressedButtonImage, for: [.highlighted])
				self.isLoadingObject = false
			}
		}
	}
    
    func loadVirtualObjectWithPoint(object: VirtualObject, point: CGPoint) {
        let spinner = UIActivityIndicatorView()
        spinner.center = addObjectButton.center
        spinner.bounds.size = CGSize(width: addObjectButton.bounds.width - 5, height: addObjectButton.bounds.height - 5)
        addObjectButton.setImage(#imageLiteral(resourceName: "buttonring"), for: [])
        sceneView.addSubview(spinner)
        spinner.startAnimating()
        
        print("loadVirtualObject")

        DispatchQueue.global().async {
            self.isLoadingObject = true
            object.viewController = self
            VirtualObjectsManager.shared.addVirtualObject(virtualObject: object)
            VirtualObjectsManager.shared.setVirtualObjectSelected(virtualObject: object)

            object.loadModel()
            VirtualObjectsManager.shared.getVirtualObjectSelected()?.translateBasedOnScreenPos(point, instantly: true, infinitePlane: false)
            DispatchQueue.main.async {
//                if let lastFocusSquarePos = self.focusSquare?.lastPosition {
//                    self.setNewVirtualObjectPosition(lastFocusSquarePos)
//                } else {
//                    self.setNewVirtualObjectPosition(SCNVector3Zero)
//                }

                spinner.removeFromSuperview()

                // Update the icon of the add object button
                let buttonImage = UIImage.composeButtonImage(from: object.thumbImage)
                let pressedButtonImage = UIImage.composeButtonImage(from: object.thumbImage, alpha: 0.3)
                self.addObjectButton.setImage(buttonImage, for: [])
                self.addObjectButton.setImage(pressedButtonImage, for: [.highlighted])
                self.isLoadingObject = false
            }
        }
    }
}

// MARK: - ARSCNViewDelegate
extension MainViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
            guard let frame = sceneView.session.currentFrame,
                  let depthData = frame.capturedDepthData else { return }
            
            let depthWidth = CVPixelBufferGetWidth(depthData.depthDataMap)
            let depthHeight = CVPixelBufferGetHeight(depthData.depthDataMap)
            print("Depth resolution: \(depthWidth)x\(depthHeight)")
            
            // Use the depth data here
            // ...
        }
    
	func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
		refreshFeaturePoints()

		DispatchQueue.main.async {
			self.updateFocusSquare()
			self.hitTestVisualization?.render()

			// If light estimation is enabled, update the intensity of the model's lights and the environment map
			if let lightEstimate = self.session.currentFrame?.lightEstimate {
				self.sceneView.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 40)
			} else {
				self.sceneView.enableEnvironmentMapWithIntensity(25)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor {
				self.addPlane(node: node, anchor: planeAnchor)
				self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor {
				if let plane = self.planes[planeAnchor] {
					plane.update(planeAnchor)
				}
				self.checkIfObjectShouldMoveOntoPlane(anchor: planeAnchor)
			}
		}
	}

	func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
		DispatchQueue.main.async {
			if let planeAnchor = anchor as? ARPlaneAnchor, let plane = self.planes.removeValue(forKey: planeAnchor) {
				plane.removeFromParentNode()
			}
		}
	}
}

// MARK: Virtual Object Manipulation
extension MainViewController {
	func displayVirtualObjectTransform() {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		// Output the current translation, rotation & scale of the virtual object as text.
		let cameraPos = SCNVector3.positionFromTransform(cameraTransform)
		let vectorToCamera = cameraPos - object.position

		let distanceToUser = vectorToCamera.length()

		var angleDegrees = Int(((object.eulerAngles.y) * 180) / Float.pi) % 360
		if angleDegrees < 0 {
			angleDegrees += 360
		}

		let distance = String(format: "%.2f", distanceToUser)
		let scale = String(format: "%.2f", object.scale.x)
//        print("distance", distance)
//        print("scale", scale)
		textManager.showDebugMessage("Distance: \(distance) m\nRotation: \(angleDegrees)°\nScale: \(scale)x")
	}

	func moveVirtualObjectToPosition(_ pos: SCNVector3?, _ instantly: Bool, _ filterPosition: Bool) {

		guard let newPosition = pos else {
			textManager.showMessage("Cannot place object\nTry moving left or right.")
			// Reset the content selection in the menu only if the content has not yet been initially placed.
			if !VirtualObjectsManager.shared.isAVirtualObjectPlaced() {
				resetVirtualObject()
			}
			return
		}

		if instantly {
			setNewVirtualObjectPosition(newPosition)
		} else {
			updateVirtualObjectPosition(newPosition, filterPosition)
		}
	}

	func worldPositionFromScreenPosition(_ position: CGPoint,
	                                     objectPos: SCNVector3?,
	                                     infinitePlane: Bool = false) -> (position: SCNVector3?,
																		  planeAnchor: ARPlaneAnchor?,
																		  hitAPlane: Bool) {

		// -------------------------------------------------------------------------------
		// 1. Always do a hit test against exisiting plane anchors first.
		//    (If any such anchors exist & only within their extents.)

		let planeHitTestResults = sceneView.hitTest(position, types: .existingPlaneUsingExtent)
		if let result = planeHitTestResults.first {

			let planeHitTestPosition = SCNVector3.positionFromTransform(result.worldTransform)
			let planeAnchor = result.anchor

			// Return immediately - this is the best possible outcome.
			return (planeHitTestPosition, planeAnchor as? ARPlaneAnchor, true)
		}

		// -------------------------------------------------------------------------------
		// 2. Collect more information about the environment by hit testing against
		//    the feature point cloud, but do not return the result yet.

		var featureHitTestPosition: SCNVector3?
		var highQualityFeatureHitTestResult = false

		let highQualityfeatureHitTestResults =
			sceneView.hitTestWithFeatures(position, coneOpeningAngleInDegrees: 18, minDistance: 0.2, maxDistance: 2.0)

		if !highQualityfeatureHitTestResults.isEmpty {
			let result = highQualityfeatureHitTestResults[0]
			featureHitTestPosition = result.position
			highQualityFeatureHitTestResult = true
		}

		// -------------------------------------------------------------------------------
		// 3. If desired or necessary (no good feature hit test result): Hit test
		//    against an infinite, horizontal plane (ignoring the real world).

		if (infinitePlane && dragOnInfinitePlanesEnabled) || !highQualityFeatureHitTestResult {

			let pointOnPlane = objectPos ?? SCNVector3Zero

			let pointOnInfinitePlane = sceneView.hitTestWithInfiniteHorizontalPlane(position, pointOnPlane)
			if pointOnInfinitePlane != nil {
				return (pointOnInfinitePlane, nil, true)
			}
		}

		// -------------------------------------------------------------------------------
		// 4. If available, return the result of the hit test against high quality
		//    features if the hit tests against infinite planes were skipped or no
		//    infinite plane was hit.

		if highQualityFeatureHitTestResult {
			return (featureHitTestPosition, nil, false)
		}

		// -------------------------------------------------------------------------------
		// 5. As a last resort, perform a second, unfiltered hit test against features.
		//    If there are no features in the scene, the result returned here will be nil.

		let unfilteredFeatureHitTestResults = sceneView.hitTestWithFeatures(position)
		if !unfilteredFeatureHitTestResults.isEmpty {
			let result = unfilteredFeatureHitTestResults[0]
			return (result.position, nil, false)
		}

		return (nil, nil, false)
	}

	func setNewVirtualObjectPosition(_ pos: SCNVector3) {

		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		recentVirtualObjectDistances.removeAll()

		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)

		object.position = cameraWorldPos + cameraToPosition

		if object.parent == nil {
			sceneView.scene.rootNode.addChildNode(object)
		}
	}

	func resetVirtualObject() {
		VirtualObjectsManager.shared.resetVirtualObjects()

		addObjectButton.setImage(#imageLiteral(resourceName: "add"), for: [])
		addObjectButton.setImage(#imageLiteral(resourceName: "addPressed"), for: [.highlighted])
	}

	func updateVirtualObjectPosition(_ pos: SCNVector3, _ filterPosition: Bool) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected() else {
			return
		}

		guard let cameraTransform = session.currentFrame?.camera.transform else {
			return
		}

		let cameraWorldPos = SCNVector3.positionFromTransform(cameraTransform)
		var cameraToPosition = pos - cameraWorldPos
		cameraToPosition.setMaximumLength(DEFAULT_DISTANCE_CAMERA_TO_OBJECTS)

		// Compute the average distance of the object from the camera over the last ten
		// updates. If filterPosition is true, compute a new position for the object
		// with this average. Notice that the distance is applied to the vector from
		// the camera to the content, so it only affects the percieved distance of the
		// object - the averaging does _not_ make the content "lag".
		let hitTestResultDistance = CGFloat(cameraToPosition.length())

		recentVirtualObjectDistances.append(hitTestResultDistance)
		recentVirtualObjectDistances.keepLast(10)

		if filterPosition {
			let averageDistance = recentVirtualObjectDistances.average!

			cameraToPosition.setLength(Float(averageDistance))
			let averagedDistancePos = cameraWorldPos + cameraToPosition

			object.position = averagedDistancePos
		} else {
			object.position = cameraWorldPos + cameraToPosition
		}
	}

	func checkIfObjectShouldMoveOntoPlane(anchor: ARPlaneAnchor) {
		guard let object = VirtualObjectsManager.shared.getVirtualObjectSelected(),
			let planeAnchorNode = sceneView.node(for: anchor) else {
			return
		}

		// Get the object's position in the plane's coordinate system.
		let objectPos = planeAnchorNode.convertPosition(object.position, from: object.parent)

		if objectPos.y == 0 {
			return; // The object is already on the plane
		}

		// Add 10% tolerance to the corners of the plane.
		let tolerance: Float = 0.1

		let minX: Float = anchor.center.x - anchor.extent.x / 2 - anchor.extent.x * tolerance
		let maxX: Float = anchor.center.x + anchor.extent.x / 2 + anchor.extent.x * tolerance
		let minZ: Float = anchor.center.z - anchor.extent.z / 2 - anchor.extent.z * tolerance
		let maxZ: Float = anchor.center.z + anchor.extent.z / 2 + anchor.extent.z * tolerance

		if objectPos.x < minX || objectPos.x > maxX || objectPos.z < minZ || objectPos.z > maxZ {
			return
		}

		// Drop the object onto the plane if it is near it.
		let verticalAllowance: Float = 0.03
		if objectPos.y > -verticalAllowance && objectPos.y < verticalAllowance {
			textManager.showDebugMessage("OBJECT MOVED\nSurface detected nearby")

			SCNTransaction.begin()
			SCNTransaction.animationDuration = 0.5
			SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
			object.position.y = anchor.transform.columns.3.y
			SCNTransaction.commit()
		}
	}
}
