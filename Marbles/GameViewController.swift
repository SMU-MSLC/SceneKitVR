//
//  GameViewController.swift
//  BouncyBall
//



import UIKit
import SceneKit
import CoreMotion


class GameViewController : UIViewController {
    
    // MARK: Properties
	// properties to set by entering controller
    var imageToShow = "texture" // replace this with the image name, in segue to controller
    // Possible Objects to Find
    var objectsToFind = ["Candles","Table","Couch","Rug","TV","Fireplace"]
    
    // SCN setup
    var scene : SCNScene!
	var cameraNode : SCNNode!
    var wallNode: SCNNode!
	var motionManager : CMMotionManager!
    var initialAttitude: (roll: Double, pitch:Double, yaw:Double)?
    
    // anmations for labels
    let animation = CATransition()
    let animationKey = convertFromCATransitionType(CATransitionType.push)
    
    // game state tracking variables
    var currentObjectToFind = "Nothing"
    var head = -1;
    var updating = false
	
    // outlets
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var sceneView: SCNView!
    @IBOutlet weak var topLabel: UILabel!
    @IBOutlet weak var middleLabel: UILabel!
    
    // MARK: View Controller Life Cycle
    override func viewDidLoad() {
		super.viewDidLoad()
        
        // for nice animations on the text
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.type = convertToCATransitionType(animationKey)
        animation.duration = 0.5
        
		// Setup environment
        addLivingRoom() // make scene
        addTapGestureToSceneView()  // make taps for selecting objects
        setupMotion() // use motion to control camera
        
        
	}
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        let deadlineTime = DispatchTime.now() + 1
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.setNextObjectToFind() // start the game and tell user what object to use!
        }
    }
    
    func setNextObjectToFind(){
        if(updating){return}
        // change the current object we are asking the participant to find
        if(head+1 < objectsToFind.count){
            // if here, there are still more objects to find
            // increment
            head += 1
            currentObjectToFind = objectsToFind[head]
            
            topLabel.layer.add(animation, forKey: animationKey)
            topLabel.text = currentObjectToFind
        }else{
            // if here, they found the last item! End the game
            topLabel.layer.add(animation, forKey: animationKey)
            topLabel.text = "You found all the items!"
            currentObjectToFind = "A super long string that cannot be found in the data!"
            // setting currentObjectToFind to something odd means it cannot
            // be found in the scene
            doneButton.layer.add(animation, forKey: animationKey)
            doneButton.isHidden = false
        }
        updating = false
    }
    
    func setupMotion(){
        // use motion for camera movement
        motionManager = CMMotionManager()
        motionManager.deviceMotionUpdateInterval = 1/30.0
        
        motionManager.startDeviceMotionUpdates(to: OperationQueue.main)
        {
            (deviceMotion, error) -> Void in
            
            if let deviceMotion = deviceMotion{
                if (self.initialAttitude == nil)
                {
                    // save initial orientaton of phone
                    // this is a reference point, we could also set these
                    // manually, assuming a starting phone orientation
                    self.initialAttitude = (deviceMotion.attitude.roll,
                                            deviceMotion.attitude.pitch,
                                            deviceMotion.attitude.yaw)
                }
                
                if let initialAttitude = self.initialAttitude{
                    // update camera angle based upon the difference to original position
                    let pitch = Float(initialAttitude.pitch - deviceMotion.attitude.pitch)
                    let yaw = Float(initialAttitude.yaw - deviceMotion.attitude.yaw)
                    
                    // euler angles define rotation of rigid body
                    // the x,y,z angles correspond to pitch, yaw, and roll, respectively
                    // so this code will adjust the camera view in response to phone position
                    self.cameraNode.eulerAngles.x = -pitch
                    self.cameraNode.eulerAngles.y = -yaw
                }
                

                // here we setup the gravity in the world to update with the phone
                self.scene.physicsWorld.gravity.x =  Float(deviceMotion.gravity.x)*9.8
                self.scene.physicsWorld.gravity.y =  Float(deviceMotion.gravity.y)*9.8
                self.scene.physicsWorld.gravity.z = -9.8 // always have gravity down //Float(deviceMotion.gravity.z)*9.8
                
            }
            
        }
    }
    
    
    // MARK: Scene Setup
    func addLivingRoom(){
        
        guard let sceneView = sceneView else {
            fatalError("Fatal Error, could not capture scene view")
        }
        
        // Setup Original Scene
        scene = SCNScene()

        // load living room model we created in sketchup
        guard let room = SCNScene(named: "Room.scn") else {
            fatalError("Could not load room scene")
        }
        
        // load the root node (the living room) from the room scene as a child
        scene.rootNode.addChildNode(room.rootNode.childNode(withName: "SketchUp", recursively: true)!)
        //room.physicsWorld.gravity = SCNVector3(x: 0, y: 0, z: -9.8)

        // add custom texture to the TV in scene, if we have the texture pack
        if let TV = room.rootNode.childNode(withName: "screen", recursively: true),
            let image = UIImage(named: imageToShow)
        {
            let material = SCNMaterial()
            material.diffuse.contents = image
            TV.geometry?.firstMaterial = material
            scene.rootNode.addChildNode(TV)
        }
        
        // Setup camera position from existing scene
        guard let cameraNode = room.rootNode.childNode(withName: "camera", recursively: true) else{
            fatalError("Fatal Error, could not load camera from scene")
        }
        self.cameraNode = cameraNode
        scene.rootNode.addChildNode(self.cameraNode)
        
        // add lighting from the room scene
        if let lighting = room.rootNode.childNode(withName: "Lighting", recursively: true){
                scene.rootNode.addChildNode(lighting)
            }
        
        // make this the scene in the view
        sceneView.scene = scene
        
        //Debugging
        sceneView.showsStatistics = true
    

    }
    
    @IBAction func doneButtonPressed(_ sender: UIButton) {
        // this button was enabled by end of game, time to go away
        self.dismiss(animated: true, completion: nil)
    }
    
    func addTapGestureToSceneView() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.handleObjectTap(_:)))
        sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func handleObjectTap(_ sender:UITapGestureRecognizer){
        if(updating){return}
        updating = true // prevent from tapping wildly
        
        // what did the user tap? Anything?
        // 1. get 2D location in view
        let tapLocation = sender.location(in: sceneView)
        // 2. test if this hits any nodes in the room scene, in 3D
        let hitTestResults = sceneView.hitTest(tapLocation)
        
        // setup a recurrsion for finding in the parent
        func findName(_ node:SCNNode?)->Bool{
            if let node = node{
                if let name = node.name{
                    return name.contains(currentObjectToFind) || findName(node.parent)
                }else{
                    return findName(node.parent)
                }
            }else{
                return false
            }
        }
        
        // for each node, use recursion to get if it has name of object
        var found = false;
        for res in hitTestResults{
            if(findName(res.node)){
                found = true
            }
        }
        
        if(found){
            // they tapped the object!
            displayBriefly("Correct!")
            
            // wait one second and update the object
            let deadlineTime = DispatchTime.now() + 1
            DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
                self.updating = false
                self.setNextObjectToFind()
            }
        }else{
            // display feedback that they havent found anything yet
            displayBriefly("Try Again!")
            self.updating = false
            
            // add sphere to the world to make things harder
            addBall()
            
        }
        
    }
    
    func addBall(){
        //let sphere = SCNNode(geometry: SCNCylinder(radius: 5, height: 3))
        let sphere = SCNNode(geometry: SCNSphere(radius: 5))
        
        // add a red ball
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.red
        
        // that can bounce around the room environment
        let physics = SCNPhysicsBody(type: .dynamic,
                                     shape:SCNPhysicsShape(geometry: sphere.geometry!, options:nil))

        physics.isAffectedByGravity = true
        physics.friction = 1
        physics.restitution = 2.5
        physics.mass = 3
        
        
        sphere.geometry?.firstMaterial = material
        sphere.position = cameraNode.position
        sphere.physicsBody = physics

        
        scene.rootNode.addChildNode(sphere)
    }
	
    func displayBriefly(_ text:String){
        // display quickly on screen and then move out
        middleLabel.layer.add(animation,forKey:animationKey)
        middleLabel.text = text
        let deadlineTime = DispatchTime.now() + 0.5
        DispatchQueue.main.asyncAfter(deadline: deadlineTime) {
            self.middleLabel.layer.add(self.animation,forKey:self.animationKey)
            self.middleLabel.text = ""
        }
    }

}



// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromCATransitionType(_ input: CATransitionType) -> String {
	return input.rawValue
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToCATransitionType(_ input: String) -> CATransitionType {
	return CATransitionType(rawValue: input)
}
