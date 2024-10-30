//
//  ViewController.swift
//  cs7323_lab4
//
//  Created by Chip Henderson on 10/27/24.
//

import UIKit
import Vision

class ViewController: UIViewController {
    
    //    // AVCapture variables to hold sequence data
    //    var session: AVCaptureSession?
    //    var previewLayer: AVCaptureVideoPreviewLayer?
    //
    //    var videoDataOutput: AVCaptureVideoDataOutput?
    //    var videoDataOutputQueue: DispatchQueue?
    //
    //    var captureDevice: AVCaptureDevice?
    //    var captureDeviceResolution: CGSize = CGSize()
    //
    //    // Layer UI for drawing Vision results
    //    var rootLayer: CALayer?
    //    var detectionOverlayLayer: CALayer?
    //    var detectedFaceRectangleShapeLayer: CAShapeLayer?
    //    var detectedFaceLandmarksShapeLayer: CAShapeLayer?
    
    // setup drawing layers for showing output of face detection
    //self.setupVisionDrawingLayers()
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    // ---------- HandPoseDetionCompletionHandler to  View Controller?  ------------
//    // define behavior for when we detect a hand pose
//    func handPoseDetectionCompletionHandler(request: VNRequest, error: Error?) {
//        // any errors? If yes, show and try to keep going
//        if error != nil {
//            print("HandPoseDetection error: \(String(describing: error)).")
//        }
//
//        // see if we can get any hand pose features, this will fail if no hand pose detected
//        // try to save the hand pose observations to a results vector
//        guard
//            let handPoseDetectionRequest = request
//                as? VNDetectHumanHandPoseRequest,
//            let results = handPoseDetectionRequest.results
//        else {
//            return
//        }
//
//        if !results.isEmpty {
//            print("Initial Hand Pose found... setting up tracking.")
//
//        }
//
//        // if we got here, then a face was detected and we have its features saved
//        // The above hand pose detection was the most computational part of what we did
//        // the remaining tracking only needs the results vector of hand features
//        // so we can process it in the main queue (because we will us it to update UI)
//        DispatchQueue.main.async {
//            // Add the face features to the tracking list
//            for observation in results {
//                let handPoseTrackingRequest = VNTrackObjectRequest(
//                    detectedObjectObservation: observation)
//                // the array starts empty, but this will constantly add to it
//                // since on the main queue, there are no race conditions
//                // everything is from a single thread
//                // once we add this, it kicks off tracking in another function
//                self.trackingRequests?.append(handPoseTrackingRequest)
//
//                // NOTE: if the initial hand pose detection is actually not a hand,
//                // then the app will continually mess up trying to perform tracking
//            }
//        }
//
//    }

    
    
    // ---------- AVCaputreVideoDataOutput functionality to  View Controller?  ------------
    //    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    //    /// - Tag: PerformRequests
    //    // Handle delegate method callback on receiving a sample buffer.
    //    // This is where we get the pixel buffer from the camera and need to
    //    // generate the vision requests
    //    public func captureOutput(
    //        _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    //        from connection: AVCaptureConnection
    //    ) {
    //
    //        var requestHandlerOptions: [VNImageOption: AnyObject] = [:]
    //
    //        // see if camera has any instrinsic transforms on it
    //        // if it does, add these to the options for requests
    //        let cameraIntrinsicData = CMGetAttachment(
    //            sampleBuffer,
    //            key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
    //            attachmentModeOut: nil)
    //        if cameraIntrinsicData != nil {
    //            requestHandlerOptions[VNImageOption.cameraIntrinsics] =
    //                cameraIntrinsicData
    //        }
    //
    //        // check to see if we can get the pixels for processing, else return
    //        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    //        else {
    //            print(
    //                "Failed to obtain a CVPixelBuffer for the current output frame."
    //            )
    //            return
    //        }
    //
    //        guard let requests = self.trackingRequests else {
    //            print("Tracking request array not setup, aborting.")
    //            return
    //        }
    //
    //        // check to see if the tracking request is empty (no face currently detected)
    //        // if it is empty,
    //        if requests.isEmpty {
    //            // No tracking object detected, so perform initial detection
    //            // the initial detection takes some time to perform
    //            // so we special case it here
    //
    //            self.performInitialDetection(
    //                pixelBuffer: pixelBuffer,
    //                exifOrientation: exifOrientation,
    //                requestHandlerOptions: requestHandlerOptions)
    //
    //            return  // just perform the initial request
    //        }
    //
    //        // if tracking was not empty, it means we have detected a hand pose very recently
    //        // so now we can process the sequence of tracking hand pose features
    //
    //        self.performTracking(
    //            requests: requests,
    //            pixelBuffer: pixelBuffer,
    //            exifOrientation: exifOrientation)
    //
    //        // if there are no valid observations, then this will be empty
    //        // the function above will empty out all the elements
    //        // in our tracking if nothing is high confidence in the output
    //        if let newTrackingRequests = self.trackingRequests {
    //
    //            if newTrackingRequests.isEmpty {
    //                // Nothing was high enough confidence to track, just abort.
    //                print("Hand object lost, resetting detection...")
    //                return
    //            }
    //
    //            self.performLandmarkDetection(
    //                newTrackingRequests: newTrackingRequests,
    //                pixelBuffer: pixelBuffer,
    //                exifOrientation: exifOrientation,
    //                requestHandlerOptions: requestHandlerOptions)
    //
    //        }
    //
    //    }
    
    
    // ---------   supporting function for AVCaptureVideoData to View Controller?
    //    // functionality to run the image detection on pixel buffer
    //    // This is an involved computation, so beware of running too often
    //    func performInitialDetection(
    //        pixelBuffer: CVPixelBuffer, exifOrientation: CGImagePropertyOrientation,
    //        requestHandlerOptions: [VNImageOption: AnyObject]
    //    ) {
    //        // create request
    //        let imageRequestHandler = VNImageRequestHandler(
    //            cvPixelBuffer: pixelBuffer,
    //            orientation: exifOrientation,
    //            options: requestHandlerOptions)
    //
    //        do {
    //            if let detectRequests = self.detectionRequests {
    //                // try to detect face and add it to tracking buffer
    //                try imageRequestHandler.perform(detectRequests)
    //            }
    //        } catch let error as NSError {
    //            NSLog("Failed to perform HandPoseRequest: %@", error)
    //        }
    //    }

        
    // ---------   supporting function for AVCaptureVideoData to View Controller?
    //    // this function performs all the tracking of the hand pose sequence
    //    func performTracking(
    //        requests: [VNTrackObjectRequest],
    //        pixelBuffer: CVPixelBuffer, exifOrientation: CGImagePropertyOrientation
    //    ) {
    //        do {
    //            // perform tracking on the pixel buffer, which is
    //            // less computational than fully detecting a face
    //            // if a face was not correct initially, this tracking
    //            //   will also be not great... but it is fast!
    //            try self.sequenceRequestHandler.perform(
    //                requests,
    //                on: pixelBuffer,
    //                orientation: exifOrientation)
    //        } catch let error as NSError {
    //            NSLog("Failed to perform SequenceRequest: %@", error)
    //        }
    //
    //        // if there are any tracking results, let's process them here
    //
    //        // Setup the next round of tracking.
    //        var newTrackingRequests = [VNTrackObjectRequest]()
    //        for trackingRequest in requests {
    //
    //            // any valid results in the request?
    //            // if so, grab the first request
    //            if let results = trackingRequest.results,
    //                let observation = results[0] as? VNDetectedObjectObservation
    //            {
    //
    //                // is this tracking request of high confidence?
    //                // If it is, then we should add it to processing buffer
    //                // the threshold is arbitrary. You can adjust to you liking
    //                if !trackingRequest.isLastFrame {
    //                    if observation.confidence > 0.3 {
    //                        trackingRequest.inputObservation = observation
    //                    } else {
    //
    //                        // once below thresh, make it last frame
    //                        // this will stop the processing of tracker
    //                        trackingRequest.isLastFrame = true
    //                    }
    //                    // add to running tally of high confidence observations
    //                    newTrackingRequests.append(trackingRequest)
    //                }
    //
    //            }
    //
    //        }
    //        self.trackingRequests = newTrackingRequests
    //
    //    }

    // ---------   supporting function for AVCaptureVideoData to View Controller?
    //    func performLandmarkDetection(
    //        newTrackingRequests: [VNTrackObjectRequest], pixelBuffer: CVPixelBuffer,
    //        exifOrientation: CGImagePropertyOrientation,
    //        requestHandlerOptions: [VNImageOption: AnyObject]
    //    ) {
    //        // Perform face landmark tracking on detected faces.
    //        // setup an empty arry for now
    //        var faceLandmarkRequests = [VNDetectFaceLandmarksRequest]()
    //
    //        // Perform landmark detection on tracked faces.
    //        for trackingRequest in newTrackingRequests {
    //
    //            // create a request for facial landmarks
    //            let faceLandmarksRequest = VNDetectFaceLandmarksRequest(
    //                completionHandler: self.landmarksCompletionHandler)
    //
    //            // get tracking result and observation for result
    //            if let trackingResults = trackingRequest.results,
    //                let observation = trackingResults[0]
    //                    as? VNDetectedObjectObservation
    //            {
    //
    //                // save the observation info
    //                let faceObservation = VNFaceObservation(
    //                    boundingBox: observation.boundingBox)
    //
    //                // set information for face
    //                faceLandmarksRequest.inputFaceObservations = [faceObservation]
    //
    //                // Continue to track detected facial landmarks.
    //                faceLandmarkRequests.append(faceLandmarksRequest)
    //
    //                // setup for performing landmark detection
    //                let imageRequestHandler = VNImageRequestHandler(
    //                    cvPixelBuffer: pixelBuffer,
    //                    orientation: exifOrientation,
    //                    options: requestHandlerOptions)
    //
    //                do {
    //                    // try to find landmarks in face, then display in completion handler
    //                    try imageRequestHandler.perform(faceLandmarkRequests)
    //
    //                    // completion handler will now take over and finish the job!
    //                } catch let error as NSError {
    //                    NSLog("Failed to perform FaceLandmarkRequest: %@", error)
    //                }
    //            }
    //        }
    //    }


    // ---------   processing landmark results to View Controller? --------
    //    func landmarksCompletionHandler(request: VNRequest, error: Error?) {
    //
    //        if error != nil {
    //            print("FaceLandmarks error: \(String(describing: error)).")
    //        }
    //
    //        // any landmarks found that we can display? If not, return
    //        guard let landmarksRequest = request as? VNDetectFaceLandmarksRequest,
    //            let results = landmarksRequest.results
    //        else {
    //            return
    //        }
    //
    //        // Perform all UI updates (drawing) on the main queue, not the background queue on which this handler is being called.
    //        DispatchQueue.main.async {
    //            // draw the landmarks using core animation layers
    //            //self.drawFaceObservations(results)
    //        }
    //    }

}

//------  View Controller extentions to ViewController-----
//// MARK: Helper Methods
//extension UIViewController {
//
//    // Helper Methods for Error Presentation
//
//    fileprivate func presentErrorAlert(
//        withTitle title: String = "Unexpected Failure", message: String
//    ) {
//        let alertController = UIAlertController(
//            title: title, message: message, preferredStyle: .alert)
//        self.present(alertController, animated: true)
//    }
//
//    fileprivate func presentError(_ error: NSError) {
//        self.presentErrorAlert(
//            withTitle: "Failed with error \(error.code)",
//            message: error.localizedDescription)
//    }
//
//    // Helper Methods for Handling Device Orientation & EXIF
//
//    fileprivate func radiansForDegrees(_ degrees: CGFloat) -> CGFloat {
//        return CGFloat(Double(degrees) * Double.pi / 180.0)
//    }
//
//    func exifOrientationForDeviceOrientation(
//        _ deviceOrientation: UIDeviceOrientation
//    ) -> CGImagePropertyOrientation {
//
//        switch deviceOrientation {
//        case .portraitUpsideDown:
//            return .rightMirrored
//
//        case .landscapeLeft:
//            return .downMirrored
//
//        case .landscapeRight:
//            return .upMirrored
//
//        default:
//            return .leftMirrored
//        }
//    }
//
//    func exifOrientationForCurrentDeviceOrientation()
//        -> CGImagePropertyOrientation
//    {
//        return exifOrientationForDeviceOrientation(UIDevice.current.orientation)
//    }
//}
//
//// MARK: Extension for AVCapture Setup
//extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
//
//    /// - Tag: CreateCaptureSession
//    fileprivate func setupAVCaptureSession() -> AVCaptureSession? {
//        let captureSession = AVCaptureSession()
//        do {
//            let inputDevice = try self.configureFrontCamera(for: captureSession)
//            self.configureVideoDataOutput(
//                for: inputDevice.device, resolution: inputDevice.resolution,
//                captureSession: captureSession)
//            self.designatePreviewLayer(for: captureSession)
//            return captureSession
//        } catch let executionError as NSError {
//            self.presentError(executionError)
//        } catch {
//            self.presentErrorAlert(message: "An unexpected failure has occured")
//        }
//
//        self.teardownAVCapture()
//
//        return nil
//    }
//
//    /// - Tag: ConfigureDeviceResolution
//    fileprivate func highestResolution420Format(for device: AVCaptureDevice)
//        -> (format: AVCaptureDevice.Format, resolution: CGSize)?
//    {
//        var highestResolutionFormat: AVCaptureDevice.Format? = nil
//        var highestResolutionDimensions = CMVideoDimensions(width: 0, height: 0)
//
//        for format in device.formats {
//            let deviceFormat = format as AVCaptureDevice.Format
//
//            let deviceFormatDescription = deviceFormat.formatDescription
//            if CMFormatDescriptionGetMediaSubType(deviceFormatDescription)
//                == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
//            {
//                let candidateDimensions = CMVideoFormatDescriptionGetDimensions(
//                    deviceFormatDescription)
//                if (highestResolutionFormat == nil)
//                    || (candidateDimensions.width
//                        > highestResolutionDimensions.width)
//                {
//                    highestResolutionFormat = deviceFormat
//                    highestResolutionDimensions = candidateDimensions
//                }
//            }
//        }
//
//        if highestResolutionFormat != nil {
//            let resolution = CGSize(
//                width: CGFloat(highestResolutionDimensions.width),
//                height: CGFloat(highestResolutionDimensions.height))
//            return (highestResolutionFormat!, resolution)
//        }
//
//        return nil
//    }
//
//    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession)
//        throws -> (device: AVCaptureDevice, resolution: CGSize)
//    {
//        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
//            deviceTypes: [.builtInWideAngleCamera], mediaType: .video,
//            position: .front)
//
//        if let device = deviceDiscoverySession.devices.first {
//            if let deviceInput = try? AVCaptureDeviceInput(device: device) {
//                if captureSession.canAddInput(deviceInput) {
//                    captureSession.addInput(deviceInput)
//                }
//
//                if let highestResolution = self.highestResolution420Format(
//                    for: device)
//                {
//                    try device.lockForConfiguration()
//                    device.activeFormat = highestResolution.format
//                    device.unlockForConfiguration()
//
//                    return (device, highestResolution.resolution)
//                }
//            }
//        }
//
//        throw NSError(domain: "ViewController", code: 1, userInfo: nil)
//    }
//
//    /// - Tag: CreateSerialDispatchQueue
//    fileprivate func configureVideoDataOutput(
//        for inputDevice: AVCaptureDevice, resolution: CGSize,
//        captureSession: AVCaptureSession
//    ) {
//
//        let videoDataOutput = AVCaptureVideoDataOutput()
//        videoDataOutput.alwaysDiscardsLateVideoFrames = true
//
//        // Create a serial dispatch queue used for the sample buffer delegate as well as when a still image is captured.
//        // A serial dispatch queue must be used to guarantee that video frames will be delivered in order.
//        let videoDataOutputQueue = DispatchQueue(
//            label: "com.example.apple-samplecode.VisionFaceTrack")
//        videoDataOutput.setSampleBufferDelegate(
//            self, queue: videoDataOutputQueue)
//
//        if captureSession.canAddOutput(videoDataOutput) {
//            captureSession.addOutput(videoDataOutput)
//        }
//
//        videoDataOutput.connection(with: .video)?.isEnabled = true
//
//        if let captureConnection = videoDataOutput.connection(
//            with: AVMediaType.video)
//        {
//            if captureConnection.isCameraIntrinsicMatrixDeliverySupported {
//                captureConnection.isCameraIntrinsicMatrixDeliveryEnabled = true
//            }
//        }
//
//        self.videoDataOutput = videoDataOutput
//        self.videoDataOutputQueue = videoDataOutputQueue
//
//        self.captureDevice = inputDevice
//        self.captureDeviceResolution = resolution
//    }
//
//    /// - Tag: DesignatePreviewLayer
//    fileprivate func designatePreviewLayer(for captureSession: AVCaptureSession)
//    {
//        let videoPreviewLayer = AVCaptureVideoPreviewLayer(
//            session: captureSession)
//        self.previewLayer = videoPreviewLayer
//
//        videoPreviewLayer.name = "CameraPreview"
//        videoPreviewLayer.backgroundColor = UIColor.black.cgColor
//        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
//
//        if let previewRootLayer = self.previewView?.layer {
//            self.rootLayer = previewRootLayer
//
//            previewRootLayer.masksToBounds = true
//            videoPreviewLayer.frame = previewRootLayer.bounds
//            previewRootLayer.addSublayer(videoPreviewLayer)
//        }
//    }
//
//    // Removes infrastructure for AVCapture as part of cleanup.
//    fileprivate func teardownAVCapture() {
//        self.videoDataOutput = nil
//        self.videoDataOutputQueue = nil
//
//        if let previewLayer = self.previewLayer {
//            previewLayer.removeFromSuperlayer()
//            self.previewLayer = nil
//        }
//    }
//}
//
//// MARK: Extension Drawing Vision Observations
//extension ViewController {
//
//    fileprivate func setupVisionDrawingLayers() {
//        let captureDeviceResolution = self.captureDeviceResolution
//
//        let captureDeviceBounds = CGRect(
//            x: 0,
//            y: 0,
//            width: captureDeviceResolution.width,
//            height: captureDeviceResolution.height)
//
//        let captureDeviceBoundsCenterPoint = CGPoint(
//            x: captureDeviceBounds.midX,
//            y: captureDeviceBounds.midY)
//
//        let normalizedCenterPoint = CGPoint(x: 0.5, y: 0.5)
//
//        guard let rootLayer = self.rootLayer else {
//            self.presentErrorAlert(message: "view was not property initialized")
//            return
//        }
//
//        let overlayLayer = CALayer()
//        overlayLayer.name = "DetectionOverlay"
//        overlayLayer.masksToBounds = true
//        overlayLayer.anchorPoint = normalizedCenterPoint
//        overlayLayer.bounds = captureDeviceBounds
//        overlayLayer.position = CGPoint(
//            x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
//
//        let faceRectangleShapeLayer = CAShapeLayer()
//        faceRectangleShapeLayer.name = "RectangleOutlineLayer"
//        faceRectangleShapeLayer.bounds = captureDeviceBounds
//        faceRectangleShapeLayer.anchorPoint = normalizedCenterPoint
//        faceRectangleShapeLayer.position = captureDeviceBoundsCenterPoint
//        faceRectangleShapeLayer.fillColor = nil
//        faceRectangleShapeLayer.strokeColor =
//            UIColor.green.withAlphaComponent(0.7).cgColor
//        faceRectangleShapeLayer.lineWidth = 5
//        faceRectangleShapeLayer.shadowOpacity = 0.7
//        faceRectangleShapeLayer.shadowRadius = 5
//
//        let faceLandmarksShapeLayer = CAShapeLayer()
//        faceLandmarksShapeLayer.name = "FaceLandmarksLayer"
//        faceLandmarksShapeLayer.bounds = captureDeviceBounds
//        faceLandmarksShapeLayer.anchorPoint = normalizedCenterPoint
//        faceLandmarksShapeLayer.position = captureDeviceBoundsCenterPoint
//        faceLandmarksShapeLayer.fillColor = nil
//        faceLandmarksShapeLayer.strokeColor =
//            UIColor.yellow.withAlphaComponent(0.7).cgColor
//        faceLandmarksShapeLayer.lineWidth = 3
//        faceLandmarksShapeLayer.shadowOpacity = 0.7
//        faceLandmarksShapeLayer.shadowRadius = 5
//
//        overlayLayer.addSublayer(faceRectangleShapeLayer)
//        faceRectangleShapeLayer.addSublayer(faceLandmarksShapeLayer)
//        rootLayer.addSublayer(overlayLayer)
//
//        self.detectionOverlayLayer = overlayLayer
//        self.detectedFaceRectangleShapeLayer = faceRectangleShapeLayer
//        self.detectedFaceLandmarksShapeLayer = faceLandmarksShapeLayer
//
//        self.updateLayerGeometry()
//    }
//
//    fileprivate func updateLayerGeometry() {
//        guard let overlayLayer = self.detectionOverlayLayer,
//            let rootLayer = self.rootLayer,
//            let previewLayer = self.previewLayer
//        else {
//            return
//        }
//
//        CATransaction.setValue(
//            NSNumber(value: true), forKey: kCATransactionDisableActions)
//
//        let videoPreviewRect = previewLayer.layerRectConverted(
//            fromMetadataOutputRect: CGRect(x: 0, y: 0, width: 1, height: 1))
//
//        var rotation: CGFloat
//        var scaleX: CGFloat
//        var scaleY: CGFloat
//
//        // Rotate the layer into screen orientation.
//        switch UIDevice.current.orientation {
//        case .portraitUpsideDown:
//            rotation = 180
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//
//        case .landscapeLeft:
//            rotation = 90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//
//        case .landscapeRight:
//            rotation = -90
//            scaleX = videoPreviewRect.height / captureDeviceResolution.width
//            scaleY = scaleX
//
//        default:
//            rotation = 0
//            scaleX = videoPreviewRect.width / captureDeviceResolution.width
//            scaleY = videoPreviewRect.height / captureDeviceResolution.height
//        }
//
//        // Scale and mirror the image to ensure upright presentation.
//        let affineTransform = CGAffineTransform(
//            rotationAngle: radiansForDegrees(rotation)
//        )
//        .scaledBy(x: scaleX, y: -scaleY)
//        overlayLayer.setAffineTransform(affineTransform)
//
//        // Cover entire screen UI.
//        let rootLayerBounds = rootLayer.bounds
//        overlayLayer.position = CGPoint(
//            x: rootLayerBounds.midX, y: rootLayerBounds.midY)
//    }
//
//    fileprivate func addPoints(
//        in landmarkRegion: VNFaceLandmarkRegion2D, to path: CGMutablePath,
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
//
//    fileprivate func addIndicators(
//        to faceRectanglePath: CGMutablePath, faceLandmarksPath: CGMutablePath,
//        for faceObservation: VNFaceObservation
//    ) {
//        let displaySize = self.captureDeviceResolution
//
//        let faceBounds = VNImageRectForNormalizedRect(
//            faceObservation.boundingBox, Int(displaySize.width),
//            Int(displaySize.height))
//        faceRectanglePath.addRect(faceBounds)
//
//        if let landmarks = faceObservation.landmarks {
//            // Landmarks are relative to -- and normalized within --- face bounds
//            let affineTransform = CGAffineTransform(
//                translationX: faceBounds.origin.x, y: faceBounds.origin.y
//            )
//            .scaledBy(x: faceBounds.size.width, y: faceBounds.size.height)
//
//            // Treat eyebrows and lines as open-ended regions when drawing paths.
//            let openLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEyebrow,
//                landmarks.rightEyebrow,
//                landmarks.faceContour,
//                landmarks.noseCrest,
//                landmarks.medianLine,
//            ]
//            for openLandmarkRegion in openLandmarkRegions
//            where openLandmarkRegion != nil {
//                self.addPoints(
//                    in: openLandmarkRegion!, to: faceLandmarksPath,
//                    applying: affineTransform, closingWhenComplete: false)
//            }
//
//            // Draw eyes, lips, and nose as closed regions.
//            let closedLandmarkRegions: [VNFaceLandmarkRegion2D?] = [
//                landmarks.leftEye,
//                landmarks.rightEye,
//                landmarks.outerLips,
//                landmarks.innerLips,
//                landmarks.nose,
//            ]
//            for closedLandmarkRegion in closedLandmarkRegions
//            where closedLandmarkRegion != nil {
//                self.addPoints(
//                    in: closedLandmarkRegion!, to: faceLandmarksPath,
//                    applying: affineTransform, closingWhenComplete: true)
//            }
//        }
//    }
//
//    /// - Tag: DrawPaths
//    fileprivate func drawFaceObservations(
//        _ faceObservations: [VNFaceObservation]
//    ) {
//        guard
//            let faceRectangleShapeLayer = self.detectedFaceRectangleShapeLayer,
//            let faceLandmarksShapeLayer = self.detectedFaceLandmarksShapeLayer
//        else {
//            return
//        }
//
//        CATransaction.begin()
//
//        CATransaction.setValue(
//            NSNumber(value: true), forKey: kCATransactionDisableActions)
//
//        let faceRectanglePath = CGMutablePath()
//        let faceLandmarksPath = CGMutablePath()
//
//        for faceObservation in faceObservations {
//            self.addIndicators(
//                to: faceRectanglePath,
//                faceLandmarksPath: faceLandmarksPath,
//                for: faceObservation)
//        }
//
//        faceRectangleShapeLayer.path = faceRectanglePath
//        faceLandmarksShapeLayer.path = faceLandmarksPath
//
//        self.updateLayerGeometry()
//
//        CATransaction.commit()
//    }
//}

