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
                    self.initialAttitude = (deviceMotion.attitude.roll,
                                            deviceMotion.attitude.pitch,
                                            deviceMotion.attitude.yaw)
                }
                
                // update camera angle based upon the difference to original position
                let pitch = Float(self.initialAttitude!.pitch - deviceMotion.attitude.pitch)
                let yaw = Float(self.initialAttitude!.yaw - deviceMotion.attitude.yaw)
                
                self.cameraNode.eulerAngles.x = -pitch 
                self.cameraNode.eulerAngles.y = -yaw

                
            }
            
        }
    }
    
    
    // MARK: Scene Setup
    func addLivingRoom(){
        
        guard let sceneView = sceneView else {
            return
        }
        
        // Setup Original Scene
        scene = SCNScene()

        // load living room model we created in sketchup
        let room = SCNScene(named: "Room.scn")!

        // add custom texture to the TV in scene
        let material = SCNMaterial()
        material.diffuse.contents = UIImage(named: imageToShow)
        let TV = room.rootNode.childNode(withName: "screen", recursively: true)!
        TV.geometry?.firstMaterial = material
        
        scene.rootNode.addChildNode(room.rootNode.childNode(withName: "SketchUp", recursively: true)!)
        scene.rootNode.addChildNode(TV)
        
        // Setup camera position from existing scene
        cameraNode = room.rootNode.childNode(withName: "camera", recursively: true)!
        scene.rootNode.addChildNode(cameraNode)
        
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
        let tapLocation = sender.location(in: sceneView)
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
        
        // for each node, user recursion to get if it has name of object
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
        }
        
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
