//
//  ViewController.swift
//  cs7323_lab4
//
//  Created by Chip Henderson on 10/27/24.
//

import AVKit
import UIKit
import Vision

class ViewController: UIViewController {
    
    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView!
    
    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?

    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()

    // Layer UI for drawing Vision results
    var rootLayer: CALayer?
    var detectionOverlayLayer: CALayer?
    var detectedHandRectangleShapeLayer: CAShapeLayer?
    var detectedHandLandmarksShapeLayer: CAShapeLayer?
    
    // Add a CAShapeLayer for the bounding box
    private let boundingBoxLayer: CAShapeLayer = CAShapeLayer()
    
    // Add CAShapeLayers for fingers
    private let thumbTipLayer = CAShapeLayer()
    private let indexTipLayer = CAShapeLayer()
    private let middleTipLayer = CAShapeLayer()
    private let ringTipLayer = CAShapeLayer()
    private let littleTipLayer = CAShapeLayer()

    // Vision requests
    private var detectionRequests: [VNDetectHumanHandPoseRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?

    lazy var sequenceRequestHandler = VNSequenceRequestHandler()
    

    // MARK: UIViewController overrides

    override func viewDidLoad() {
        super.viewDidLoad()

        // setup video for high resolution, drop frames when busy, and front camera
        self.session = self.setupAVCaptureSession()
        
        // Add setup of BoundingBox Layer
        self.setupBoundingBoxLayer()

        // setup the vision objects for (1) detection and (2) tracking
        self.prepareVisionRequest()

        // start the capture session and get processing a hand!
        //self.session?.startRunning()

        //Wilma updated: modified to remove the Capture session warning:
        //[AVCaptureSession startRunning] should be called from background thread.
        //Calling it on the main thread can lead to UI unresponsiveness
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session?.startRunning()
        }

    }
    // Add function to setup Bounding Box Layer
    private func setupBoundingBoxLayer() {
        boundingBoxLayer.strokeColor = UIColor.red.cgColor
        boundingBoxLayer.lineWidth = 2.0
        boundingBoxLayer.fillColor = UIColor.clear.cgColor
        view.layer.addSublayer(boundingBoxLayer)
       }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // Ensure that the interface stays locked in Portrait.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // Ensure that the interface stays locked in Portrait.
    override var preferredInterfaceOrientationForPresentation:
        UIInterfaceOrientation
    {
        return .portrait
    }

    // MARK: Performing Vision Requests

    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {

        self.trackingRequests = []

        // create a detection request that processes an image and returns hand features
        // completion handler does not run immediately, it is run
        // after a hand is detected
        let handDetectionRequest: VNDetectHumanHandPoseRequest =
            VNDetectHumanHandPoseRequest(completionHandler: self.handDetectionCompletionHandler)

        // Save this detection request for later processing
        self.detectionRequests = [handDetectionRequest]

        // setup the tracking of a sequence of features from detection
        self.sequenceRequestHandler = VNSequenceRequestHandler()

        // setup drawing layers for showing output of hand detection
        self.setupVisionDrawingLayers()
    }

    // define behavior for when we detect a hand
    // MARK: Need to update this for hand...'humanHandDetection?'
    func handDetectionCompletionHandler(request: VNRequest, error: Error?) {
        // any errors? If yes, show and try to keep going
        if error != nil {
            print("HandDetection error: \(String(describing: error)).")
        }
        
        // see if we can get any hand features, this will fail if no hands detected
        // try to save the hand observations to a results vector
        guard
            let handDetectionRequest = request
                as? VNDetectHumanHandPoseRequest,
            let results = handDetectionRequest.results
        else {
            return
        }
        
        if !results.isEmpty {
            print("Initial Hand found... setting up tracking.")
            
        }
        
        // if we got here, then a hand was detected and we have its features saved
        // The above hand detection was the most computational part of what we did
        // the remaining tracking only needs the results vector of hand features
        // so we can process it in the main queue (because we will us it to update UI)
        DispatchQueue.main.async {
            // Add the hand features to the tracking list
            // ORIG: for observation in results {
            //         let handTrackingRequest = VNTrackObjectRequest(
            //              detectedObjectObservation: observation)
            
            // Wilma added: from chatGPT
            // Get the recognized points (like wrist and fingertips) for bounding box calculation
            if let observation = results.first{
                let wrist = try? observation.recognizedPoints(.all)[.wrist]
                let indexTip = try? observation.recognizedPoints(.all)[.indexTip]
                
                // Create the bounding box
                //if let wrist = wrist, let indexTip = indexTip, wrist.confidence > 0.3, indexTip.confidence > 0.3 {
                if let wrist = wrist, let indexTip = indexTip {
                    // Calculate a bounding box around the hand
                    let minX = min(wrist.location.x, indexTip.location.x)
                    let minY = min(wrist.location.y, indexTip.location.y)
                    let width = abs(wrist.location.x - indexTip.location.x)
                    let height = abs(wrist.location.y - indexTip.location.y)
                    let boundingBox = CGRect(x: minX, y: minY, width: width, height: height)
                    
                    // Convert this to a VNDetectedObjectObservation
                    let handObservation = VNDetectedObjectObservation(boundingBox: boundingBox)
                    
                    
                    // the array starts empty, but this will constantly add to it
                    // since on the main queue, there are no race conditions
                    // everything is from a single thread
                    // once we add this, it kicks off tracking in another function
                    
                    let handTrackingRequest = VNTrackObjectRequest(detectedObjectObservation: handObservation)
                    
                    self.trackingRequests?.append( handTrackingRequest)
                    
                    // NOTE: if the initial hand detection is actually not a hand,
                    // then the app will continually mess up trying to perform tracking
                }
            }
        }
    }
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    // This is where we get the pixel buffer from the camera and need to
    // generate the vision requests
    public func captureOutput(
        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {

        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]

        // see if camera has any instrinsic transforms on it
        // if it does, add these to the options for requests
        let cameraIntrinsicData = CMGetAttachment(
            sampleBuffer,
            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
            attachmentModeOut: nil)
        if cameraIntrinsicData != nil {
            requestHandlerOptions[VNImageOption.cameraIntrinsics] =
                cameraIntrinsicData
        }

        // check to see if we can get the pixels for processing, else return
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else {
            print(
                "Failed to obtain a CVPixelBuffer for the current output frame."
            )
            return
        }

        // get portrait orientation for UI
        let exifOrientation = self.exifOrientationForCurrentDeviceOrientation()

        guard let requests = self.trackingRequests else {
            print("Tracking request array not setup, aborting.")
            return
        }

        // check to see if the tracking request is empty (no hand currently detected)
        // if it is empty,
        if requests.isEmpty {
            // No tracking object detected, so perform initial detection
            // the initial detection takes some time to perform
            // so we special case it here

            self.performInitialDetection(
                pixelBuffer: pixelBuffer,
                exifOrientation: exifOrientation,
                requestHandlerOptions: requestHandlerOptions)

            return  // just perform the initial request
        }

        // if tracking was not empty, it means we have detected a hand very recently
        // so no we can process the sequence of tracking hand features

        self.performTracking(
            requests: requests,
            pixelBuffer: pixelBuffer,
            exifOrientation: exifOrientation)

        // if there are no valid observations, then this will be empty
        // the function above will empty out all the elements
        // in our tracking if nothing is high confidence in the output
        if let newTrackingRequests = self.trackingRequests {

            if newTrackingRequests.isEmpty {
                // Nothing was high enough confidence to track, just abort.
                print("Hand object lost, resetting detection...")
                return
            }

            self.performLandmarkDetection(
                newTrackingRequests: newTrackingRequests,
                pixelBuffer: pixelBuffer,
                exifOrientation: exifOrientation,
                requestHandlerOptions: requestHandlerOptions)

        }

    }

    // functionality to run the image detection on pixel buffer
    // This is an involved computation, so beware of running too often
    func performInitialDetection(
        pixelBuffer: CVPixelBuffer, exifOrientation: CGImagePropertyOrientation,
        requestHandlerOptions: [VNImageOption: AnyObject]
    ) {
        // create request
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: exifOrientation,
            options: requestHandlerOptions)

        do {
            if let detectRequests = self.detectionRequests {
                // try to detect hand and add it to tracking buffer
                try imageRequestHandler.perform(detectRequests)
            }
        } catch let error as NSError {
            NSLog("Failed to perform HandRectangleRequest: %@", error)
        }
    }

    // this function performs all the tracking of the hand sequence
    func performTracking(
        requests: [VNTrackObjectRequest],
        pixelBuffer: CVPixelBuffer, exifOrientation: CGImagePropertyOrientation
    ) {
        do {
            // perform tracking on the pixel buffer, which is
            // less computational than fully detecting a hand
            // if a hand was not correct initially, this tracking
            //   will also be not great... but it is fast!
            try self.sequenceRequestHandler.perform(
                requests,
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
                let observation = results[0] as? VNDetectedObjectObservation
            {

                // is this tracking request of high confidence?
                // If it is, then we should add it to processing buffer
                // the threshold is arbitrary. You can adjust to you liking
                if !trackingRequest.isLastFrame {
                    if observation.confidence > 0.3 {
                        trackingRequest.inputObservation = observation
                        
                        //Wilma: add for bounding box
                        let boundingBox = trackingRequest.inputObservation.boundingBox
                        
                        // Update the bounding box layer
                        DispatchQueue.main.async {
                            //Convert Vision's bounding box to view coordinates
                            let convertedBoundingBox = VNImageRectForNormalizedRect(boundingBox, Int(self.view.bounds.width), Int(self.view.bounds.height))
                            //self.drawBoundingBox(convertedBoundingBox)
                        }
                    } else {

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

    func drawBoundingBox(_ boundingBox: CGRect) {
        let path = UIBezierPath(rect: boundingBox)
        boundingBoxLayer.path = path.cgPath
    }

    
    
    func performLandmarkDetection(
        newTrackingRequests: [VNTrackObjectRequest], pixelBuffer: CVPixelBuffer,
        exifOrientation: CGImagePropertyOrientation,
        requestHandlerOptions: [VNImageOption: AnyObject]
    ) {
        // Perform hand landmark tracking on detected hands.
        // setup an empty arry for now
        var handLandmarkRequests = [VNDetectHumanHandPoseRequest]()

        // Perform landmark detection on tracked hands.
        for trackingRequest in newTrackingRequests {

            // create a request for hand landmarks
            let handLandmarksRequest = VNDetectHumanHandPoseRequest(
                completionHandler: self.landmarksCompletionHandler)

            // get tracking result and observation for result
            if let trackingResults = trackingRequest.results,
                let observation = trackingResults[0]
                    as? VNDetectedObjectObservation
            {

                // save the observation info
                let handObservation = VNFaceObservation(
                    boundingBox: observation.boundingBox)

                // set information for hand
                // NOTE: This doesn't work with humanHandObservations
//                handLandmarksRequest.inputHandObservations = [handObservation]

                // Continue to track detected facial landmarks.
                handLandmarkRequests.append(handLandmarksRequest)

                // setup for performing landmark detection
                let imageRequestHandler = VNImageRequestHandler(
                    cvPixelBuffer: pixelBuffer,
                    orientation: exifOrientation,
                    options: requestHandlerOptions)

                do {
                    // try to find landmarks in hand, then display in completion handler
                    try imageRequestHandler.perform(handLandmarkRequests)

                    // completion handler will now take over and finish the job!
                } catch let error as NSError {
                    NSLog("Failed to perform HandLandmarkRequest: %@", error)
                }
            }
        }
    }

    /// Mark: - Eye Tracking Methods
    
    // Interpret the output of our facial landmark detector
    // this code is called upon succesful completion of landmark detection
    fileprivate func saveMaxValues(
        _ minY: CGPoint, _ maxY: CGPoint, _ minX: CGPoint, _ maxX: CGPoint
    ) {
        //1.3.1  what is the smallest “min x” or “min y” landmark you observed across frames?
        //1.3.2  What is the largest “max x” or “max y” landmark you observed across frames?
        //1.3.3  Store these tracked extrema as class properties that are named tuples.
        // Store tracked extrema
//        if var leftEyeY {
//            if Float(minY.y) < leftEyeY.min {
//                leftEyeY.min = Float(minY.y)
//                //print("leftEyeY.min = \((leftEyeY.min))")
//            }
//            if Float(maxY.y) > leftEyeY.max {
//                leftEyeY.max = Float(maxY.y)
//                //print("leftEyeY.max = \((leftEyeY.max))")
//            }
//
//        } else {
//            leftEyeY = (Float(minY.y), Float(maxY.y))
//        }
//
//        if var leftEyeX {
//
//            if Float(minX.x) < leftEyeX.min {
//                leftEyeX.min = Float(minX.x)
//                //print("leftEyeX.min= \((leftEyeX.min))")
//            }
//
//            if Float(maxX.x) > leftEyeX.max {
//                leftEyeX.max = Float(maxX.x)
//                //print("leftEyeX.max= \((leftEyeX.max))")
//            }
//
//        } else {
//            leftEyeX = (Float(minX.x), Float(maxX.x))
//        }
    }

    /// Filter the y difference to make it more stable
//    private func filterYDiff(currYDiff: Float) {
//        // we will filter the y difference to make it more stable
//        // in order to help detect blinking
//        if let filteredYDiff = self.filteredYDiff {
//            self.filteredYDiff! -= filteredYDiff / 3
//            self.filteredYDiff! += currYDiff / 3
//        } else {
//            self.filteredYDiff = currYDiff
//        }
//
//    }

//    /// Check if the user is blinking based on the filtered y difference and the current y difference
//    fileprivate func checkForBlinking(_ currYDiff: Float) {
//        if isBlinking {
//            // if we are blinking, then we need to check if we stop
//            if currYDiff > 1.12 * filteredYDiff! {
//                // if the y difference is greater than 112% of the filtered y difference
//                // assume they are not blinking (the filtered y diff was reset when they started blinking
//                // so it only has values from when they eye was closed)
//                isBlinking = false
//                // reset the filteredYDiff
//                filteredYDiff = nil
//                print("Not Blinking!!")
//            }
//        } else {
//            // if we are not blinking, then we need to check if we start
//            if currYDiff < 0.88 * filteredYDiff! {
//                // if the y difference is less than 88% of the filtered y difference
//                // assume they are blinking (the filtered y diff was reset when they started blinking
//                // so it only has values from when they eye was open)
//                isBlinking = true
//                // reset the filteredYDiff
//                filteredYDiff = nil
//                print("Blinking!!")
//            }
//        }
//    }

    /// Detect the gaze of the user based on the eye and pupil positions
//    private func detectGaze(_ lePoints: [CGPoint], _ ppPoints: [CGPoint])
//        -> Float
//    {
//
//        // Find min and max x positions of the eye
//        let minEye = lePoints.min { a, b in a.x < b.x }?.x ?? 0
//        let maxEye = lePoints.max { a, b in a.x < b.x }?.x ?? 1
//
//        // Define the margins of the eye where the pupil
//        // does not appear (these values are experimental)
//        let leftEyeMargin = 0.3 * (maxEye - minEye)
//        let rightEyeMargin = 0.4 * (maxEye - minEye)
//        
//        // Define the boundaries of the pupil range within the eye
//        // this helps us normalize the gaze value to a range of [0,1]
//        let leftBoundary = minEye + leftEyeMargin
//        let rightBoundary = maxEye - rightEyeMargin
//
//        // Find min and max x positions of the pupil
//        let minPupil =
//            ppPoints.min { a, b in a.x < b.x }?.x ?? 0
//        let maxPupil =
//            ppPoints.max { a, b in a.x < b.x }?.x ?? 1
//
//        // Calculate the center of the pupil
//        let pupilCenter = (minPupil + maxPupil) / 2.0
//
//        // Calculate the raw gaze position relative to the left boundary
//        let rawGaze = pupilCenter - leftBoundary
//
//        // Calculate the effective pupil range (distance between boundaries)
//        let pupilRange = rightBoundary - leftBoundary
//
//        // Normalize the gaze within the defined pupil range
//        let normalizedGaze = rawGaze / pupilRange
//
//        // Clamp the gaze value between 0 and 1
//        return min(1, max(0, Float(normalizedGaze)))
//    }

    /// Filter the gaze value to make it more stable
//    private func filterGaze(_ gaze: Float) {
//        if let filteredGaze = self.filteredGaze {
//            self.filteredGaze! -= filteredGaze / 5
//            self.filteredGaze! += gaze / 5
//        } else {
//            self.filteredGaze = gaze
//        }
//    }

    func landmarksCompletionHandler(request: VNRequest, error: Error?)
    {

        if error != nil {
            print("HandLandmarks error: \(String(describing: error)).")
        }

        // any landmarks found that we can display? If not, return
        guard let landmarksRequest = request as? VNDetectHumanHandPoseRequest,
            let results = landmarksRequest.results
        else {
            return
        }

        // Assuming `results` contains the hand pose observations from `VNDetectHumanHandPoseRequest`
        if let results = landmarksRequest.results, let handObservation = results.first {
            do {
                // Access recognized points (landmarks) for different fingers
                let thumbPoints = try handObservation.recognizedPoints(.thumb)
                let indexFingerPoints = try handObservation.recognizedPoints(.indexFinger)
                let middleFingerPoints = try handObservation.recognizedPoints(.middleFinger)
                let ringFingerPoints = try handObservation.recognizedPoints(.ringFinger)
                let littleFingerPoints = try handObservation.recognizedPoints(.littleFinger)
                
                // Each dictionary contains points like .tip, .dip, .pip, .mcp, etc.
                if let thumbTip = thumbPoints[.thumbTip],
                   let indexTip = indexFingerPoints[.indexTip],
                   let middleTip = middleFingerPoints[.middleTip],
                   let ringTip = ringFingerPoints[.ringTip],
                   let littleTip = littleFingerPoints[.littleTip] {

                    // Ensure points are confidently detected
                    if thumbTip.confidence > 0.3, indexTip.confidence > 0.3,
                       middleTip.confidence > 0.3, ringTip.confidence > 0.3,
                       littleTip.confidence > 0.3 {

                        // Convert these points to view coordinates if needed
                        let thumbTipLocation = thumbTip.location
                        let indexTipLocation = indexTip.location
                        let middleTipLocation = middleTip.location
                        let ringTipLocation = ringTip.location
                        let littleTipLocation = littleTip.location
                        
                        // Here, you can add these points to a drawing layer or use them to perform gestures detection
                        print("Thumb Tip: \(thumbTipLocation)")
                        print("Index Tip: \(indexTipLocation)")
                        print("Middle Tip: \(middleTipLocation)")
                        print("Ring Tip: \(ringTipLocation)")
                        print("Little Tip: \(littleTipLocation)")
                    }
                }
            } catch {
                print("Error accessing hand landmarks: \(error)")
            }
        }

//        if let handObservation = results.first {
//            if let landmarks = handObservation.landmarks,
//                let lePoints = landmarks.leftEye?.normalizedPoints
//            {
//                // The normalized points are normalized to the range of [0,1]
//                // based on the bounding box of the hand
//                guard let minY = lePoints.min(by: { a, b in a.y < b.y }),
//                    let maxY = lePoints.max(by: { a, b in a.y < b.y }),
//                    let minX = lePoints.min(by: { a, b in a.x < b.x }),
//                    let maxX = lePoints.max(by: { a, b in a.x < b.x })
//                else {
//                    // if we can't get the min and max values don't continue
//                    return
//                }
//
//                saveMaxValues(minY, maxY, minX, maxX)
//
//                let currYDiff = Float(maxY.y - minY.y)
//                greatestYDiff = max(greatestYDiff, currYDiff)
//                
//                print("Current Y Diff: \(currYDiff), Greatest Y Diff: \(greatestYDiff)")
//                
//                filterYDiff(currYDiff: currYDiff)
//
//                checkForBlinking(currYDiff)
//
//                // Gaze tracking
//                if !isBlinking {
//                    if let ppPoints = landmarks.leftPupil?.normalizedPoints {
//                        // only detect gaze if the user is not blinking
//                        // and the pupil is detected
//                        let gaze = detectGaze(lePoints, ppPoints)
//                        filterGaze(gaze)
//                        print("Gaze: \(filteredGaze ?? gaze)")
//                    }
//
//                } else {
//                    // if the gaze is not detected, then set it to nil
//                    self.gaze = nil
//                    self.filteredGaze = nil
//                }
//
//            }
//        }

        // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
//        DispatchQueue.main.async {
//            if let gaze = self.filteredGaze {
//                // if the gaze is detected, update the slider value
//                self.slider.value = gaze
//            }
//            // draw the landmarks using core animation layers
//            self.drawHandObservations(results)
//        }
    }

}

// MARK: Helper Methods
extension UIViewController {

    // Helper Methods for Error Presentation

    fileprivate func presentErrorAlert(
        withTitle title: String = "Unexpected Failure", message: String
    ) {
        let alertController = UIAlertController(
            title: title, message: message, preferredStyle: .alert)
        self.present(alertController, animated: true)
    }

    fileprivate func presentError(_ error: NSError) {
        self.presentErrorAlert(
            withTitle: "Failed with error \(error.code)",
            message: error.localizedDescription)
    }

    // Helper Methods for Handling Device Orientation & EXIF

    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
        return CGFloat(Double(degrees) * Double.pi / 180.0)
    }

    func exifOrientationForDeviceOrientation(
        _ deviceOrientation: UIDeviceOrientation
    ) -> CGImagePropertyOrientation {

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

    func exifOrientationForCurrentDeviceOrientation()
        -> CGImagePropertyOrientation
    {
       return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
    }
}

// MARK: Extension for AVCapture Setup
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    /// - Tag: CreateCaptureSession
    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
        let captureSession = AVCaptureSession()
        do {
            //let inputDevice = try self.configureFrontCamera(for: captureSession)
            let inputDevice = try self.configureBackCamera(for: captureSession)
            self.configureVideoDataOutput(
                for: inputDevice.device, resolution: inputDevice.resolution,
                captureSession: captureSession)
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
    fileprivate func highestResolution420Format(for device: AVCaptureDevice)
        -> (format: AVCaptureDevice.Format, resolution: CGSize)?
    {
        var highestResolutionFormat: AVCaptureDevice.Format? = nil
        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)

        for format in device.formats {
            let deviceFormat = format as AVCaptureDevice.Format

            let deviceFormatDescription = deviceFormat.formatDescription
            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription)
                == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            {
                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(
                    deviceFormatDescription)
                if (highestResolutionFormat == nil)
                    || (candidateDimensions.width
                        > highestResolutionDimensions.width)
                {
                    highestResolutionFormat = deviceFormat
                    highestResolutionDimensions = candidateDimensions
                }
            }
        }

        if highestResolutionFormat != nil {
            let resolution = CGSize(
                width: CGFloat(highestResolutionDimensions.width),
                height: CGFloat(highestResolutionDimensions.height))
            return (highestResolutionFormat!, resolution)
        }

        return nil
    }

    fileprivate func configureBackCamera(for captureSession: AVCaptureSession)
        throws -> (device: AVCaptureDevice, resolution: CGSize)
    {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video,
            position: .back)

        if let device = deviceDiscoverySession.devices.first {
            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
                if captureSession.canAddInput(deviceInput) {
                    captureSession.addInput(deviceInput)
                }

                if let highestResolution = self.highestResolution420Format(
                    for: device)
                {
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
    fileprivate func configureVideoDataOutput(
        for inputDevice: AVCaptureDevice, resolution: CGSize,
        captureSession: AVCaptureSession
    ) {

        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.alwaysDiscardsLateVideoFrames = true

        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
        let videoDataOutputQueue = DispatchQueue(
            label: "com.example.apple-samplecode.VisionHandTrack")
        videoDataOutput.setSampleBufferDelegate(
            self, queue: videoDataOutputQueue)

        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }

        videoDataOutput.connection(with: .video)?.isEnabled = true

        if let captureConnection = videoDataOutput.connection(
            with: AVMediaType.video)
        {
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
    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession)
    {
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(
            session: captureSession)
        self.previewLayer = videoPreviewLayer

        videoPreviewLayer.name = "CameraPreview"
        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill

        if let previewRootLayer = self.previewView?.layer {
            self.rootLayer = previewRootLayer

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

// MARK: Extension Drawing Vision Observations
extension ViewController {

    fileprivate func setupVisionDrawingLayers() {
        let captureDeviceResolution = self.captureDeviceResolution

        let captureDeviceBounds = CGRect(
            x: 0,
            y: 0,
            width: captureDeviceResolution.width,
            height: captureDeviceResolution.height)

        let captureDeviceBoundsCenterPoint = CGPoint(
            x: captureDeviceBounds.midX,
            y: captureDeviceBounds.midY)

        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)

        guard let rootLayer = self.rootLayer else {
            self.presentErrorAlert(message: "view was not property initialized")
            return
        }

        let overlayLayer = CALayer()
        overlayLayer.name = "DetectionOverlay"
        overlayLayer.masksToBounds = true
        overlayLayer.anchorPoint = normalizedCenterPoint
        overlayLayer.bounds = captureDeviceBounds
        overlayLayer.position = CGPoint(
            x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)

        let handRectangleShapeLayer = CAShapeLayer()
        handRectangleShapeLayer.name = "RectangleOutlineLayer"
        handRectangleShapeLayer.bounds = captureDeviceBounds
        handRectangleShapeLayer.anchorPoint = normalizedCenterPoint
        handRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
        handRectangleShapeLayer.fillColor = nil
        handRectangleShapeLayer.strokeColor =
            UIColor.green.withAlphaComponent(0.7).cgColor
        handRectangleShapeLayer.lineWidth = 5
        handRectangleShapeLayer.shadowOpacity = 0.7
        handRectangleShapeLayer.shadowRadius = 5

        let handLandmarksShapeLayer = CAShapeLayer()
        handLandmarksShapeLayer.name = "HandLandmarksLayer"
        handLandmarksShapeLayer.bounds = captureDeviceBounds
        handLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
        handLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
        handLandmarksShapeLayer.fillColor = nil
        handLandmarksShapeLayer.strokeColor =
            UIColor.yellow.withAlphaComponent(0.7).cgColor
        handLandmarksShapeLayer.lineWidth = 3
        handLandmarksShapeLayer.shadowOpacity = 0.7
        handLandmarksShapeLayer.shadowRadius = 5

        overlayLayer.addSublayer(handRectangleShapeLayer)
        handRectangleShapeLayer.addSublayer(handLandmarksShapeLayer)
        rootLayer.addSublayer(overlayLayer)

        self.detectionOverlayLayer = overlayLayer
        self.detectedHandRectangleShapeLayer = handRectangleShapeLayer
        self.detectedHandLandmarksShapeLayer = handLandmarksShapeLayer

        self.updateLayerGeometry()
    }

    fileprivate func updateLayerGeometry() {
        guard let overlayLayer = self.detectionOverlayLayer,
            let rootLayer = self.rootLayer,
            let previewLayer = self.previewLayer
        else {
            return
        }

        CATransaction.setValue(
            NSNumber(value: true), forKey: kCATransactionDisableActions)

        let videoPreviewRect = previewLayer.layerRectConverted(
            fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))

        var rotation: CGFloat
        var scaleX: CGFloat
        var scaleY: CGFloat

        // Rotate the layer into screen orientation.
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            rotation = 180
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height

        case .landscapeLeft:
            rotation = 90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        case .landscapeRight:
            rotation = -90
            scaleX = videoPreviewRect.height / captureDeviceResolution.width
            scaleY = scaleX

        default:
            rotation = 0
            scaleX = videoPreviewRect.width / captureDeviceResolution.width
            scaleY = videoPreviewRect.height / captureDeviceResolution.height
        }

        // Scale and mirror the image to ensure upright presentation.
        let affineTransform = CGAffineTransform(
            rotationAngle: radiansForDegrees(rotation)
        )
        .scaledBy(x: scaleX, y: -scaleY)
        overlayLayer.setAffineTransform(affineTransform)

        // Cover entire screen UI.
        let rootLayerBounds = rootLayer.bounds
        overlayLayer.position = CGPoint(
            x: rootLayerBounds.midX, y: rootLayerBounds.midY)
    }

//Wilma    fileprivate func addPoints(
//        in landmarkRegion: VNHandLandmarkRegion2D, to path: CGMutablePath,
//        applying affineTransform: CGAffineTransform,
//        closingWhenComplete closePath: Bool
//    ) {
//        let pointCount = landmarkRegion.pointCount
//        if pointCount > 1 {
//            let points: [CGPoint] = landmarkRegion.normalizedPoints
//            path.move(to: points[0], transform: affineTransform)
//            path.addLines(between: points, transform: affineTransform)
//            if closePath {
//                path.addLine(to: points[0], transform: affineTransform)
//                path.closeSubpath()
//            }
//        }
//    }

//Wilma:    fileprivate func addIndicators(
//        to handRectanglePath: CGMutablePath, handLandmarksPath: CGMutablePath,
//        for handObservation: VNHumanHandPoseObservation
//    ) {
//        let displaySize = self.captureDeviceResolution
//
//        let handBounds = VNImageRectForNormalizedRect(
//            handObservation.boundingBox, Int(displaySize.width),
//            Int(displaySize.height))
//        handRectanglePath.addRect(handBounds)
//
//        if let landmarks = handObservation.landmarks {
//            // Landmarks are relative to -- and normalized within --- hand bounds
//            let affineTransform = CGAffineTransform(
//                translationX: handBounds.origin.x, y: handBounds.origin.y
//            )
//            .scaledBy(x: handBounds.size.width, y: handBounds.size.height)
//
//            // Treat eyebrows and lines as open-ended regions when drawing paths.
//            let openLandmarkRegions: [VNHandLandmarkRegion2D?] = [
//                landmarks.leftEyebrow,
//                landmarks.rightEyebrow,
//                landmarks.handContour,
//                landmarks.noseCrest,
//                landmarks.medianLine,
//            ]
//            for openLandmarkRegion in openLandmarkRegions
//            where openLandmarkRegion != nil {
//                self.addPoints(
//                    in: openLandmarkRegion!, to: handLandmarksPath,
//                    applying: affineTransform, closingWhenComplete: false)
//            }
//
//            // Draw eyes, lips, and nose as closed regions.
//            let closedLandmarkRegions: [VNHandLandmarkRegion2D?] = [
//                landmarks.leftEye,
//                landmarks.rightEye,
//                landmarks.outerLips,
//                landmarks.innerLips,
//                landmarks.nose,
//            ]
//            for closedLandmarkRegion in closedLandmarkRegions
//            where closedLandmarkRegion != nil {
//                self.addPoints(
//                    in: closedLandmarkRegion!, to: handLandmarksPath,
//                    applying: affineTransform, closingWhenComplete: true)
//            }
//        }
//    }

//Wilma:    /// - Tag: DrawPaths
//    fileprivate func drawHandObservations(
//        _ handObservations: [VNHumanHandPoseObservation]
//    ) {
//        guard
//            let handRectangleShapeLayer = self.detectedHandRectangleShapeLayer,
//            let handLandmarksShapeLayer = self.detectedHandLandmarksShapeLayer
//        else {
//            return
//        }
//
//        CATransaction.begin()
//
//        CATransaction.setValue(
//            NSNumber(value: true), forKey: kCATransactionDisableActions)
//
//        let handRectanglePath = CGMutablePath()
//        let handLandmarksPath = CGMutablePath()
//
//        for handObservation in handObservations {
//            self.addIndicators(
//                to: handRectanglePath,
//                handLandmarksPath: handLandmarksPath,
//                for: handObservation)
//        }
//
//        handRectangleShapeLayer.path = handRectanglePath
//        handLandmarksShapeLayer.path = handLandmarksPath
//
//        self.updateLayerGeometry()
//
//        CATransaction.commit()
//    }
}
