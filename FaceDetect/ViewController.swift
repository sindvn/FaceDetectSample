//
//  ViewController.swift
//  FaceDetect
//
//  Created by Si Nguyen on 11/27/17.
//  Copyright © 2017 Origin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    private var faceService : FaceDetectionService!
    
    @IBOutlet weak var imageV: UIImageView!
    @IBOutlet weak var catchButton: UIButton!
    
    var image : UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //Setup with a camera-position (iSight-Camera (Back), FaceTime-Camera (Front)) and an optimization mode for either better feature-recognition performance (HighPerformance) or better battery-life (BatteryLife)
        faceService = FaceDetectionService(cameraPosition: .FaceTimeCamera, optimizeFor: .HigherPerformance)
        
        //If you enable "onlyFireNotificationOnStatusChange" you won't get a continuous "stream" of notifications, but only one notification once the status changes.
        faceService.onlyFireNotificatonOnStatusChange = false
        
        
        //You need to call "beginFaceDetection" to start the detection, but also if you want to use the cameraView.
        faceService.beginFaceDetection()
        
        //This is a very simple cameraView you can use to preview the image that is seen by the camera.
        let cameraView = faceService.appCameraView
        self.view.insertSubview(cameraView, at: 0)
        
        //Subscribing to the "visageFaceDetectedNotification" (for a list of all available notifications check out the "ReadMe" or switch to "Visage.swift") and reacting to it with a completionHandler. You can also use the other .addObserver-Methods to react to notifications.
        NotificationCenter.default.addObserver(forName: FaceDetectionService.NotificationType.appFaceDetectedNotification.name, object: nil, queue: OperationQueue.main, using: { notification in
            
            if let image = notification.object as? UIImage {
                self.imageV.image = image
            }
            self.catchButton.alpha = 1
            self.catchButton.isEnabled = true
            
            if ((self.faceService.hasSmile == true && self.faceService.isWinking == true)) {
                
            } else if ((self.faceService.isWinking == true && self.faceService.hasSmile == false)) {
                
            } else if ((self.faceService.hasSmile == true && self.faceService.isWinking == false)) {
                
            } else {
                
            }
        })
        
        //The same thing for the opposite, when no face is detected things are reset.
        NotificationCenter.default.addObserver(forName: FaceDetectionService.NotificationType.appNoFaceDetectedNotification.name, object: nil, queue: OperationQueue.main, using: { notification in
            self.imageV.image = nil
            self.catchButton.alpha = 0.8
            self.catchButton.isEnabled = false
        })
    }


}

