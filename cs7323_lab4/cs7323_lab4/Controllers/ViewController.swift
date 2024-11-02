/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import UIKit
import AVKit
import Vision

class ViewController: UIViewController {
    
    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView?
    
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?
    
    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()
    
    // Vision requests
    private var detectionRequests: [VNDetectFaceRectanglesRequest]?
//    private var detectionRequests: [VNDetectHumanHandPoseRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    private var handPoseRequest = VNDetectHumanHandPoseRequest()
    
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    
    // Define CAShapeLayer properties for fingertip markers
    private var thumbTipLayer = CAShapeLayer()
    private var indexTipLayer = CAShapeLayer()
    private var middleTipLayer = CAShapeLayer()
    private var ringTipLayer = CAShapeLayer()
    private var littleTipLayer = CAShapeLayer()
    private var wristLayer = CAShapeLayer()
    
    private var boundingBoxLayer = CAShapeLayer()


    
    // MARK: UIViewController overrides
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // setup video for high resolution, drop frames when busy, and front camera
        self.session = self.setupAVCaptureSession()
        
        // setup the vision objects for (1) detection and (2) tracking
        self.prepareVisionRequest()
        
        // start the capture session and get processing a face!
        self.session?.startRunning()
        
        // Limit to one hand
        handPoseRequest.maximumHandCount = 1
        
        // Configure CAShapeLayers
        setupFingertipLayers()
    }
    
    
    private func setupFingertipLayers() {
        // Configure layers for thumb and index finger tips
        [thumbTipLayer, indexTipLayer, middleTipLayer, ringTipLayer, littleTipLayer, wristLayer].forEach { layer in
            layer.fillColor = UIColor.red.cgColor
            layer.strokeColor = UIColor.clear.cgColor
            layer.bounds = CGRect(x: 0, y: 0, width: 10, height: 10) // Circle size
            layer.cornerRadius = 5 // Half of the width/height for a circle
            layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
            previewView?.layer.addSublayer(layer)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
    
    
    
    // MARK: Performing Vision Requests
    
    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {
        
        self.trackingRequests = []
        
        // create a detection request that processes an image and returns face features
        // completion handler does not run immediately, it is run
        // after a face is detected
        let faceDetectionRequest:VNDetectFaceRectanglesRequest = VNDetectFaceRectanglesRequest(completionHandler: self.faceDetectionCompletionHandler)
        
        // Save this detection request for later processing
        self.detectionRequests = [faceDetectionRequest]
        
        // setup the tracking of a sequence of features from detection
        self.sequenceRequestHandler = VNSequenceRequestHandler()
        
    }
    
    // define behavior for when we detect a face
    func faceDetectionCompletionHandler(request:VNRequest, error: Error?){
        // any errors? If yes, show and try to keep going
        if error != nil {
            print("FaceDetection error: \(String(describing: error)).")
        }
        
        // see if we can get any face features, this will fail if no faces detected
        // try to save the face observations to a results vector
        guard let faceDetectionRequest = request as? VNDetectFaceRectanglesRequest,
            let results = faceDetectionRequest.results as? [VNFaceObservation] else {
                return
        }
//        guard let handDetectionRequest = request as? VNDetectHumanHandPoseRequest,
//              let results = handDetectionRequest.results as? [VNHumanObservation] else {
//                return
//        }
        if !results.isEmpty{
            print("Initial Face found... setting up tracking.")
        }
        
        // the remaining tracking only needs the results vector of face features
        // so we can process it in the main queue (because we will us it to update UI)
        DispatchQueue.main.async {
            // Add the face features to the tracking list
            for observation in results {
                let faceTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
//                let handTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: observation)
                // the array starts empty, but this will constantly add to it
                // since on the main queue, there are no race conditions
                // everything is from a single thread
                // once we add this, it kicks off tracking in another function
                self.trackingRequests?.append(faceTrackingRequest)
//                self.trackingRequest?.append(handTrackingRequest)
                
                // NOTE: if the initial face detection is actually not a face,
                // then the app will continually mess up trying to perform tracking
            }
        }
    }
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    // This is where we get the pixel buffer from the camera and need to
    // generate the vision requests
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
        
        // see if camera has any instrinsic transforms on it
        // if it does, add these to the options for requests
        let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] = cameraIntrinsicData
        }
        
        // check to see if we can get the pixels for processing, else return
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("Failed to obtain a CVPixelBuffer for the current output frame.")
            return
        }
        // get portrait orientation for UI
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()
        
        guard let requests = self.trackingRequests else {
            print("Tracking request array not setup, aborting.")
            return
        }
        
        // check to see if the tracking request is empty (no face currently detected)
        // if it is empty,
        if requests.isEmpty{
            // No tracking object detected, so perform initial detection
            // the initial detection takes some time to perform
            // so we special case it here
            
            self.performInitialDetection(pixelBuffer: pixelBuffer,
                                        exifOrientation: exifOrientation,
                                        requestHandlerOptions: requestHandlerOptions)
            
            return  // just perform the initial request
        }
        
        // if tracking was not empty, it means we have detected a face very recently
        // so we can process the sequence of tracking face features
        self.performTracking(requests: requests,
                             pixelBuffer: pixelBuffer,
                             exifOrientation: exifOrientation)
        // if there are no valid observations, then this will be empty
        // the function above will empty out all the elements
        // in our tracking if nothing is high confidence in the output
        if let newTrackingRequests = self.trackingRequests{
            if newTrackingRequests.isEmpty {
                // Nothing was high enough confidence to track, just abort.
                print("Face object lost, resetting detection...")
                return
            }
        }
    }
    
    // functionality to run the image detection on pixel buffer
    // This is an involved computation, so beware of running too often
    func performInitialDetection(pixelBuffer:CVPixelBuffer, exifOrientation:CGImagePropertyOrientation, requestHandlerOptions:[VNImageOption: AnyObject]) {
        var thumbTip: CGPoint?
        var indexTip: CGPoint?
        var middleTip: CGPoint?
        var ringTip: CGPoint?
        var littleTip: CGPoint?
        var wristPoint: CGPoint?
        
        // create request
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                                        orientation: exifOrientation,
                                                        options: requestHandlerOptions)
        
        do {
            try imageRequestHandler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                return
            }
            
            
            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(.indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(.middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(.littleFinger)
            //let wristPoints = try observation.recognizedPoints(.all)[.wrist]
            let wristPoints = try observation.recognizedPoint(.wrist)
            
            // Look for tip points.
            guard let thumbTipPoint = thumbPoints[.thumbTip], thumbTipPoint.confidence > 0.5,
                  let indexTipPoint = indexFingerPoints[.indexTip], indexTipPoint.confidence > 0.5,
                  let middleTipPoint = middleFingerPoints[.middleTip], middleTipPoint.confidence > 0.5,
                  let ringTipPoint = ringFingerPoints[.ringTip], ringTipPoint.confidence > 0.5,
                  let littleTipPoint = littleFingerPoints[.littleTip], littleTipPoint.confidence > 0.5
                  //let wristPoint = wristPoint, wristPoint.confidence > 0.5
                  //let wristPoints = wristPoint
            else {
                return
            }
            
            //            // Ignore low confidence points.
            //            guard thumbTipPoint.confidence > 0.3 && indexTipPoint.confidence > 0.3 else {
            //                return
            //            }
            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = CGPoint(x: thumbTipPoint.location.x * previewView!.frame.width,
                               y: (1 - thumbTipPoint.location.y) * previewView!.frame.height)
            indexTip = CGPoint(x: indexTipPoint.location.x * previewView!.frame.width,
                               y: (1 - indexTipPoint.location.y) * previewView!.frame.height)
            middleTip = CGPoint(x: middleTipPoint.location.x * previewView!.frame.width,
                                y: (1 - middleTipPoint.location.y) * previewView!.frame.height)
            ringTip = CGPoint(x: ringTipPoint.location.x * previewView!.frame.width,
                              y: (1 - ringTipPoint.location.y) * previewView!.frame.height)
            littleTip = CGPoint(x: littleTipPoint.location.x * previewView!.frame.width,
                                y: (1 - littleTipPoint.location.y) * previewView!.frame.height)
            wristPoint = CGPoint(x: (wristPoints.location.x) * previewView!.frame.width,
                                             y: (1 - (wristPoints.location.y)) * previewView!.frame.height)
            
            print("Thumb: ", thumbTip)
            print("Index: ", indexTip)
            print("Middle: ", middleTip)
            print("Ring: ", ringTip)
            print("Little: ", littleTip)
            print("wrist: ", wristPoints)
            

            
            DispatchQueue.main.async {
                self.thumbTipLayer.position = thumbTip ?? .zero
                self.indexTipLayer.position = indexTip ?? .zero
                self.middleTipLayer.position = middleTip ?? .zero
                self.ringTipLayer.position = ringTip ?? .zero
                self.littleTipLayer.position = littleTip ?? .zero
                self.wristLayer.position = wristPoint ?? .zero
                
                //Get Bounding box
                // Get all points in the hand
                guard let allPoints = try? observation.recognizedPoints(.all) else {
                    print("Error getting allPoints in obervation.recognizedPoints(.all)")
                    return }
                
                //Calculate bounding rectangle
                // Extract x coord and y coord from all points.
                let xCoordinates = allPoints.values.map { $0.location.x }
                let yCoordinates = allPoints.values.map { $0.location.y }
                
                // Find min and max x and y to create a bounding rectangle
                if let minX = xCoordinates.min(),
                   let maxX = xCoordinates.max(),
                   let minY = yCoordinates.min(),
                   let maxY = yCoordinates.max() {
                    let boundingRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
                    // Use `boundingRect` as the hand's bounding box
                    self.drawBoundingBox(boundingBox: boundingRect)
                }
            }
        } catch let error as NSError {
            NSLog("Failed to perform FaceRectangleRequest: %@", error)
        }
    }
    
    // Wilma added draw bounding box
    func drawBoundingBox(boundingBox: CGRect) {
        // Convert bounding rectangle to the view's coordinate system
        let viewWidth = view.bounds.width
        let viewHeight = view.bounds.height
        let scaledRect = CGRect(
            x: boundingBox.origin.x * viewWidth,
            y: (1 - boundingBox.origin.y) * viewHeight - boundingBox.height * viewHeight,
            width: boundingBox.width * viewWidth,
            height: boundingBox.height * viewHeight
        )
       
        // Create a shape layer
        boundingBoxLayer.path = UIBezierPath(rect: scaledRect).cgPath
        boundingBoxLayer.strokeColor = UIColor.red.cgColor
        boundingBoxLayer.fillColor = UIColor.clear.cgColor
        boundingBoxLayer.lineWidth = 2.0
        
        // Add the shape layer to the view
        view.layer.addSublayer(boundingBoxLayer)
    }
    // end Wilma added draw bounding box
    
    
    // this function performs all the tracking of the face sequence
    func performTracking(requests:[VNTrackObjectRequest],
                         pixelBuffer:CVPixelBuffer, exifOrientation:CGImagePropertyOrientation)
    {
        do {
            // perform tracking on the pixel buffer, which is
            // less computational than fully detecting a face
            // if a face was not correct initially, this tracking
            //   will also be not great... but it is fast!
            try self.sequenceRequestHandler.perform(requests,
                                                    on: pixelBuffer,
                                                    orientation: exifOrientation)
        } catch let error as NSError {
            NSLog("Failed to perform SequenceRequest: %@", error)
        }
        
        // if there are any tracking results, let's process them here
        
        // Setup the next round of tracking.
        var newTrackingRequests = [VNTrackObjectRequest]()
        for trackingRequest in requests {
            
            // any valid results in the request?
            // if so, grab the first request
            if let results = trackingRequest.results,
               let observation = results[0] as? VNDetectedObjectObservation {
                
                
                // is this tracking request of high confidence?
                // If it is, then we should add it to processing buffer
                // the threshold is arbitrary. You can adjust to you liking
                if !trackingRequest.isLastFrame {
                    if observation.confidence < 0.3 {

                        // once below thresh, make it last frame
                        // this will stop the processing of tracker
                        trackingRequest.isLastFrame = true
                    }
                    // add to running tally of high confidence observations
                    newTrackingRequests.append(trackingRequest)
                }
                
            }
            
        }
        self.trackingRequests = newTrackingRequests
        
        
    }
      
    
}


// MARK: Helper Methods
extension UIViewController{
    
    // Helper Methods for Error Presentation
    
    fileprivate func presentErrorAlert(withTitle title: String = "Unexpected Failure", message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }
    
    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(withTitle: "Failed with error \(error.code)", message: error.localizedDescription)
    }
    
    // Helper Methods for Handling Device Orientation & EXIF
    
    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }
    
    func exifOrientationForDeviceOrientation(_ deviceOrientation: UIDeviceOrientation) -> CGImagePropertyOrientation {
        
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .rightMirrored
            
        case .landscapeLeft:
            return .downMirrored
            
        case .landscapeRight:
            return .upMirrored
            
        default:
            return .leftMirrored
        }
    }
    
    func exifOrientationForCurrentDeviceOrientation() -> CGImagePropertyOrientation {
        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}


// MARK: Extension for AVCapture Setup
extension ViewController:AVCaptureVideoDataOutputSampleBufferDelegate{
    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            let inputDevice = try self.configureFrontCamera(for: captureSession)
            self.configureVideoDataOutput(for: inputDevice.device, resolution: inputDevice.resolution, captureSession: captureSession)
            self.designatePreviewLayer(for: captureSession)
            return captureSession
        } catch let executionError as NSError {
            self.presentError(executionError)
        } catch {
            self.presentErrorAlert(message: "An unexpected failure has occured")
        }
        
        self.teardownAVCapture()
        
        return nil
    }
    
    /// - Tag: ConfigureDeviceResolution
    fileprivate func highestResolution420Format(for device: AVCaptureDevice) -> (format: AVCaptureDevice.Format, resolution: CGSize)? {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
        
        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format
            
            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription) == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(deviceFormatDescription)
                if (highestResolutionFormat == nil) || (candidateDimensions.width > highestResolutionDimensions.width) {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }
        
        if highestResolutionFormat != nil {
            let resolution = CGSize(width: CGFloat(highestResolutionDimensions.width), height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }
        
        return nil
    }
    
    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession) throws -> (device: AVCaptureDevice, resolution: CGSize) {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .front)
        
        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }
                
                if let highestResolution = self.highestResolution420Format(for: device) {
                    try device.lockForConfiguration()
                    device.activeFormat = highestResolution.format
                    device.unlockForConfiguration()
                    
                    return (device, highestResolution.resolution)
                }
            }
        }
        
        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
    }
    
    /// - Tag: CreateSerialDispatchQueue
    fileprivate func configureVideoDataOutput(for inputDevice: AVCaptureDevice, resolution: CGSize, captureSession: AVCaptureSession) {
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VisionFaceTrack")
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        videoDataOutput.connection(with: .video)?.isEnabled = true
        
        if let captureConnection = videoDataOutput.connection(with: AVMediaType.video) {
            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
            }
        }
        
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = videoDataOutputQueue
        
        self.captureDevice = inputDevice
        self.captureDeviceResolution = resolution
    }
    
    /// - Tag: DesignatePreviewLayer
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession) {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.previewLayer = videoPreviewLayer
        
        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        if let previewRootLayer = self.previewView?.layer {
            
            previewRootLayer.masksToBounds = true
            videoPreviewLayer.frame = previewRootLayer.bounds
            previewRootLayer.addSublayer(videoPreviewLayer)
        }
    }
    
    // Removes infrastructure for AVCapture as part of cleanup.
    fileprivate func teardownAVCapture() {
        self.videoDataOutput = nil
        self.videoDataOutputQueue = nil
        
        if let previewLayer = self.previewLayer {
            previewLayer.removeFromSuperlayer()
            self.previewLayer = nil
        }
    }
}



