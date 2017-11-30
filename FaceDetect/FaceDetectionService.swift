//
//  FaceDetectionService.swift
//  MoneyMind
//
//  Created by Si Nguyen on 10/26/17.
//  Copyright © 2017 Origin. All rights reserved.
//

import UIKit
import CoreImage
import AVFoundation
import ImageIO

class FaceDetectionService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum NotificationType : String {
        case appNoFaceDetectedNotification
        case appFaceDetectedNotification
        case appSmilingNotification
        case appNotSmilingNotification
        case appBlinkingNotification
        case appNotBlinkingNotification
        case appWinkingNotification
        case appNotWinkingNotification
        case appLeftEyeClosedNotification
        case appLeftEyeOpenNotification
        case appRightEyeClosedNotification
        case appRightEyeOpenNotification
        
        var name : Notification.Name {
            return Notification.Name(rawValue: self.rawValue)
        }
        
        func notification(_ object: Any? = nil) -> Notification {
            return Notification(name: self.name, object:object)
        }
    }
    
    enum DetectorAccuracy {
        case BatterySaving
        case HigherPerformance
    }
    
    enum CameraDevice {
        case ISightCamera
        case FaceTimeCamera
    }
    
    var onlyFireNotificatonOnStatusChange : Bool = true
    var appCameraView : UIView = UIView()
    
    //Private properties of the detected face that can be accessed (read-only) by other classes.
    private(set) var faceDetected : Bool?
    private(set) var faceBounds : CGRect?
    private(set) var faceAngle : CGFloat?
    private(set) var faceAngleDifference : CGFloat?
    private(set) var leftEyePosition : CGPoint?
    private(set) var rightEyePosition : CGPoint?
    
    private(set) var mouthPosition : CGPoint?
    private(set) var hasSmile : Bool?
    private(set) var isBlinking : Bool?
    private(set) var isWinking : Bool?
    private(set) var leftEyeClosed : Bool?
    private(set) var rightEyeClosed : Bool?
    
    //Private variables that cannot be accessed by other classes in any way.
    private var faceDetector : CIDetector?
    private var videoDataOutput : AVCaptureVideoDataOutput?
    private var videoDataOutputQueue : DispatchQueue?
    private var cameraPreviewLayer : AVCaptureVideoPreviewLayer?
    private var captureSession : AVCaptureSession = AVCaptureSession()
    private let notificationCenter = NotificationCenter.default
    private var currentOrientation : Int?
    
    init(cameraPosition : CameraDevice, optimizeFor : DetectorAccuracy) {
        super.init()
        
        currentOrientation = convertOrientation(deviceOrientation: UIDevice.current.orientation)
        
        switch cameraPosition {
        case .FaceTimeCamera : self.captureSetup(position: .front)
        case .ISightCamera : self.captureSetup(position: .back)
        }
        
        var faceDetectorOptions : [String : AnyObject]?
        
        switch optimizeFor {
        case .BatterySaving : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyLow as AnyObject]
        case .HigherPerformance : faceDetectorOptions = [CIDetectorAccuracy : CIDetectorAccuracyHigh as AnyObject]
        }
        
        self.faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: faceDetectorOptions)
    }
    
    //MARK: SETUP OF VIDEOCAPTURE
    func beginFaceDetection() {
        self.captureSession.startRunning()
    }
    
    func endFaceDetection() {
        self.captureSession.stopRunning()
    }
    
    private func captureSetup (position : AVCaptureDevicePosition) {
        var captureError : NSError?
        var captureDevice : AVCaptureDevice!
        
        for testedDevice in AVCaptureDeviceDiscoverySession(deviceTypes: [AVCaptureDeviceType.builtInWideAngleCamera], mediaType: AVMediaTypeVideo, position: .unspecified).devices {
            if testedDevice.position == position {
                captureDevice = testedDevice
            }
        }
        
        if (captureDevice == nil) {
            captureDevice = AVCaptureDevice.defaultDevice(withMediaType: AVMediaTypeVideo)
        }
        
        var deviceInput : AVCaptureDeviceInput?
        do {
            deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        } catch let error as NSError {
            captureError = error
            deviceInput = nil
        }
        captureSession.sessionPreset = AVCaptureSessionPresetHigh
        
        if (captureError == nil) {
            if (captureSession.canAddInput(deviceInput)) {
                captureSession.addInput(deviceInput)
            }
            
            self.videoDataOutput = AVCaptureVideoDataOutput()
            self.videoDataOutput!.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable: Int(kCVPixelFormatType_32BGRA)]
            self.videoDataOutput!.alwaysDiscardsLateVideoFrames = true
            self.videoDataOutputQueue = DispatchQueue(label:"VideoDataOutputQueue", attributes: .concurrent)
            self.videoDataOutput!.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue!)
            
            if (captureSession.canAddOutput(self.videoDataOutput)) {
                captureSession.addOutput(self.videoDataOutput)
            }
        }
        
        appCameraView.frame = UIScreen.main.bounds
        
        if let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession) {
            previewLayer.frame = UIScreen.main.bounds
            previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
            appCameraView.layer.addSublayer(previewLayer)
        }
    }
    
    var options : [String : AnyObject]?
    
    //MARK: CAPTURE-OUTPUT/ANALYSIS OF FACIAL-FEATURES
    func captureOutput(_ captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, from connection: AVCaptureConnection!) {
        
        let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let opaqueBuffer = Unmanaged<CVImageBuffer>.passUnretained(imageBuffer!).toOpaque()
        let pixelBuffer = Unmanaged<CVPixelBuffer>.fromOpaque(opaqueBuffer).takeUnretainedValue()
        let sourceImage = CIImage(cvImageBuffer: pixelBuffer, options: nil)
        options = [CIDetectorSmile : true as AnyObject, CIDetectorEyeBlink: true as AnyObject, CIDetectorImageOrientation : 6 as AnyObject]
        
        let features = self.faceDetector!.features(in: sourceImage, options: options)
        
        if (features.count != 0) {
            
            let image = UIImage(ciImage: sourceImage)
            
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == false) {
                    notificationCenter.post(NotificationType.appFaceDetectedNotification.notification(image))
                }
            } else {
                notificationCenter.post(NotificationType.appFaceDetectedNotification.notification(image))
            }
            
            self.faceDetected = true
            
            for feature in features as! [CIFaceFeature] {
                faceBounds = feature.bounds
                
                if (feature.hasFaceAngle) {
                    
                    if (faceAngle != nil) {
                        faceAngleDifference = CGFloat(feature.faceAngle) - faceAngle!
                    } else {
                        faceAngleDifference = CGFloat(feature.faceAngle)
                    }
                    
                    faceAngle = CGFloat(feature.faceAngle)
                }
                
                if (feature.hasLeftEyePosition) {
                    leftEyePosition = feature.leftEyePosition
                }
                
                if (feature.hasRightEyePosition) {
                    rightEyePosition = feature.rightEyePosition
                }
                
                if (feature.hasMouthPosition) {
                    mouthPosition = feature.mouthPosition
                }
                
                if (feature.hasSmile) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == false) {
                            notificationCenter.post(NotificationType.appSmilingNotification.notification())
                        }
                    } else {
                        notificationCenter.post(NotificationType.appSmilingNotification.notification())
                    }
                    
                    hasSmile = feature.hasSmile
                    
                } else {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.hasSmile == true) {
                            notificationCenter.post(NotificationType.appNotSmilingNotification.notification())
                        }
                    } else {
                        notificationCenter.post(NotificationType.appNotSmilingNotification.notification())
                    }
                    
                    hasSmile = feature.hasSmile
                }
                
                if (feature.leftEyeClosed || feature.rightEyeClosed) {
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isWinking == false) {
                            notificationCenter.post(NotificationType.appWinkingNotification.notification())
                        }
                    } else {
                        notificationCenter.post(NotificationType.appWinkingNotification.notification())
                    }
                    
                    isWinking = true
                    
                    if (feature.leftEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.leftEyeClosed == false) {
                                notificationCenter.post(NotificationType.appLeftEyeClosedNotification.notification())
                            }
                        } else {
                            notificationCenter.post(NotificationType.appLeftEyeClosedNotification.notification())
                        }
                        
                        leftEyeClosed = feature.leftEyeClosed
                    }
                    if (feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.rightEyeClosed == false) {
                                notificationCenter.post(NotificationType.appRightEyeClosedNotification.notification())
                            }
                        } else {
                            notificationCenter.post(NotificationType.appRightEyeClosedNotification.notification())
                        }
                        
                        rightEyeClosed = feature.rightEyeClosed
                    }
                    if (feature.leftEyeClosed && feature.rightEyeClosed) {
                        if (onlyFireNotificatonOnStatusChange == true) {
                            if (self.isBlinking == false) {
                                notificationCenter.post(NotificationType.appBlinkingNotification.notification())
                            }
                        } else {
                            notificationCenter.post(NotificationType.appBlinkingNotification.notification())
                        }
                        
                        isBlinking = true
                    }
                } else {
                    
                    if (onlyFireNotificatonOnStatusChange == true) {
                        if (self.isBlinking == true) {
                            notificationCenter.post(NotificationType.appNotBlinkingNotification.notification())
                        }
                        if (self.isWinking == true) {
                            notificationCenter.post(NotificationType.appNotWinkingNotification.notification())
                        }
                        if (self.leftEyeClosed == true) {
                            notificationCenter.post(NotificationType.appLeftEyeOpenNotification.notification())
                        }
                        if (self.rightEyeClosed == true) {
                            notificationCenter.post(NotificationType.appRightEyeOpenNotification.notification())
                        }
                    } else {
                        notificationCenter.post(NotificationType.appNotBlinkingNotification.notification())
                        notificationCenter.post(NotificationType.appNotWinkingNotification.notification())
                        notificationCenter.post(NotificationType.appLeftEyeOpenNotification.notification())
                        notificationCenter.post(NotificationType.appRightEyeOpenNotification.notification())
                    }
                    
                    isBlinking = false
                    isWinking = false
                    leftEyeClosed = feature.leftEyeClosed
                    rightEyeClosed = feature.rightEyeClosed
                }
            }
        } else {
            if (onlyFireNotificatonOnStatusChange == true) {
                if (self.faceDetected == true) {
                    notificationCenter.post(NotificationType.appNoFaceDetectedNotification.notification())
                }
            } else {
                notificationCenter.post(NotificationType.appNoFaceDetectedNotification.notification())
            }
            
            self.faceDetected = false
        }
    }
    
    //TODO: 🚧 HELPER TO CONVERT BETWEEN UIDEVICEORIENTATION AND CIDETECTORORIENTATION 🚧
    private func convertOrientation(deviceOrientation: UIDeviceOrientation) -> Int {
        var orientation: Int = 0
        switch deviceOrientation {
        case .portrait:
            orientation = 6
        case .portraitUpsideDown:
            orientation = 2
        case .landscapeLeft:
            orientation = 3
        case .landscapeRight:
            orientation = 4
        default : orientation = 1
        }
        return 6
    }
}
