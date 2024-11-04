/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import AVKit
import UIKit
import Vision

class ViewController: UIViewController {

    // Main view for showing camera content.
    @IBOutlet weak var previewView: UIView?
    @IBOutlet weak var countLabel: UILabel?

    // AVCapture variables to hold sequence data
    var session: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?

    var videoDataOutput: AVCaptureVideoDataOutput?
    var videoDataOutputQueue: DispatchQueue?

    var captureDevice: AVCaptureDevice?
    var captureDeviceResolution: CGSize = CGSize()

    // Vision requests
    private var handPoseRequest = VNDetectHumanHandPoseRequest()

    private var handPose = HandPose()

    lazy var sequenceRequestHandler = VNSequenceRequestHandler()

    // Define CAShapeLayer properties for fingertip markers
    private var thumbTipLayer = CAShapeLayer()
    private var indexTipLayer = CAShapeLayer()
    private var middleTipLayer = CAShapeLayer()
    private var ringTipLayer = CAShapeLayer()
    private var littleTipLayer = CAShapeLayer()
    private var wristLayer = CAShapeLayer()

    private var thumbBaseLayer = CAShapeLayer()
    private var indexBaseLayer = CAShapeLayer()
    private var middleBaseLayer = CAShapeLayer()
    private var ringBaseLayer = CAShapeLayer()
    private var littleBaseLayer = CAShapeLayer()

    private var boundingBoxLayer = CAShapeLayer()

    // MARK: UIViewController overrides

    override func viewDidLoad() {
        super.viewDidLoad()

        handPose.delegate = self

        // setup video for high resolution, drop frames when busy, and front camera
        self.session = self.setupAVCaptureSession()

        // Start the capture session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.session?.startRunning()
        }
        // Limit to one hand
        handPoseRequest.maximumHandCount = 1

        // Configure CAShapeLayers
        setupFingertipLayers()

        setupFingerBaseLayers()

        //Setup Bounding Box Layer
        setupBoundingBoxLayer()
    }

    private func setupFingertipLayers() {
        // Configure layers for finger tips
        [
            thumbTipLayer, indexTipLayer, middleTipLayer, ringTipLayer,
            littleTipLayer, wristLayer,
        ].forEach { layer in
            if layer == wristLayer{
                layer.fillColor = UIColor.systemYellow.withAlphaComponent(0.5).cgColor
            }
            else{
                layer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
            }
            layer.strokeColor = UIColor.clear.cgColor
            layer.bounds = CGRect(x: 0, y: 0, width: 14, height: 14) // Circle size
            layer.cornerRadius = 7 // Half of the width/height for a circle
            layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
            previewView?.layer.addSublayer(layer)
        }
    }

    private func setupFingerBaseLayers() {
        // Configure layers for finger bases
        [
            thumbBaseLayer, indexBaseLayer, middleBaseLayer, ringBaseLayer,
            littleBaseLayer,
        ].forEach { layer in
            layer.fillColor = UIColor.blue.withAlphaComponent(0.5).cgColor
            layer.strokeColor = UIColor.clear.cgColor
            layer.bounds = CGRect(x: 0, y: 0, width: 10, height: 10)  // Circle size
            layer.cornerRadius = 5  // Half of the width/height for a circle
            layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
            previewView?.layer.addSublayer(layer)
        }
    }

    private func setupBoundingBoxLayer() {
        //Setup bounding box shape layer
        boundingBoxLayer.strokeColor = UIColor.red.cgColor
        boundingBoxLayer.fillColor = UIColor.clear.cgColor
        boundingBoxLayer.lineWidth = 2.0
        // Add the shape layer to the view
        previewView?.layer.addSublayer(boundingBoxLayer)
    }

    //    override func didReceiveMemoryWarning() {
    //        super.didReceiveMemoryWarning()
    //    }

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

    // Convert Vision coordinates to `previewLayer` coordinates.
    func mapToPreviewLayer(point: CGPoint) -> CGPoint? {
        guard let previewLayer = previewLayer else { return nil }
        let newPoint = CGPoint(x: 1 - point.y, y: point.x)
        var convertedPoint = previewLayer.layerPointConverted(
            fromCaptureDevicePoint: newPoint)
        return convertedPoint
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

        self.performInitialDetection(
            pixelBuffer: pixelBuffer,
            exifOrientation: exifOrientation,
            requestHandlerOptions: requestHandlerOptions)
    }

    // functionality to run the image detection on pixel buffer
    // This is an involved computation, so beware of running too often
    func performInitialDetection(
        pixelBuffer: CVPixelBuffer, exifOrientation: CGImagePropertyOrientation,
        requestHandlerOptions: [VNImageOption: AnyObject]
    ) {
        var thumbTip: CGPoint?
        var indexTip: CGPoint?
        var middleTip: CGPoint?
        var ringTip: CGPoint?
        var littleTip: CGPoint?
        var wristPoint: CGPoint?

        var thumbBase: CGPoint?
        var indexBase: CGPoint?
        var middleBase: CGPoint?
        var ringBase: CGPoint?
        var littleBase: CGPoint?

        // create request
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: exifOrientation,
            options: requestHandlerOptions)

        do {
            try imageRequestHandler.perform([handPoseRequest])
            guard let observation = handPoseRequest.results?.first else {
                return
            }

            // start hand pose update
            self.handPose.updatePose(with: observation)

            // Get points for thumb and index finger.
            let thumbPoints = try observation.recognizedPoints(.thumb)
            let indexFingerPoints = try observation.recognizedPoints(
                .indexFinger)
            let middleFingerPoints = try observation.recognizedPoints(
                .middleFinger)
            let ringFingerPoints = try observation.recognizedPoints(.ringFinger)
            let littleFingerPoints = try observation.recognizedPoints(
                .littleFinger)
            //let wristPoints = try observation.recognizedPoints(.all)[.wrist]
            let wristPoints = try observation.recognizedPoint(.wrist)

            // Look for tip and base points.
            guard let thumbTipPoint = thumbPoints[.thumbTip],
                thumbTipPoint.confidence > 0.5,
                let indexTipPoint = indexFingerPoints[.indexTip],
                indexTipPoint.confidence > 0.5,
                let middleTipPoint = middleFingerPoints[.middleTip],
                middleTipPoint.confidence > 0.5,
                let ringTipPoint = ringFingerPoints[.ringTip],
                ringTipPoint.confidence > 0.5,
                let littleTipPoint = littleFingerPoints[.littleTip],
                littleTipPoint.confidence > 0.5,

                let thumbBasePoint = thumbPoints[.thumbMP],
                thumbBasePoint.confidence > 0.5,
                let indexBasePoint = indexFingerPoints[.indexMCP],
                indexBasePoint.confidence > 0.5,
                let middleBasePoint = middleFingerPoints[.middleMCP],
                middleBasePoint.confidence > 0.5,
                let ringBasePoint = ringFingerPoints[.ringMCP],
                ringBasePoint.confidence > 0.5,
                let littleBasePoint = littleFingerPoints[.littleMCP],
                littleBasePoint.confidence > 0.5

            else {
                return
            }

            // Convert points from Vision coordinates to AVFoundation coordinates.
            thumbTip = mapToPreviewLayer(point: thumbTipPoint.location)
            indexTip = mapToPreviewLayer(point: indexTipPoint.location)
            middleTip = mapToPreviewLayer(point: middleTipPoint.location)
            ringTip = mapToPreviewLayer(point: ringTipPoint.location)
            littleTip = mapToPreviewLayer(point: littleTipPoint.location)
            wristPoint = mapToPreviewLayer(point: wristPoints.location)

            thumbBase = mapToPreviewLayer(point: thumbBasePoint.location)
            indexBase = mapToPreviewLayer(point: indexBasePoint.location)
            middleBase = mapToPreviewLayer(point: middleBasePoint.location)
            ringBase = mapToPreviewLayer(point: ringBasePoint.location)
            littleBase = mapToPreviewLayer(point: littleBasePoint.location)

            DispatchQueue.main.async {
                self.thumbTipLayer.position = thumbTip ?? .zero
                self.indexTipLayer.position = indexTip ?? .zero
                self.middleTipLayer.position = middleTip ?? .zero
                self.ringTipLayer.position = ringTip ?? .zero
                self.littleTipLayer.position = littleTip ?? .zero
                self.wristLayer.position = wristPoint ?? .zero

                self.thumbBaseLayer.position = thumbBase ?? .zero
                self.indexBaseLayer.position = indexBase ?? .zero
                self.middleBaseLayer.position = middleBase ?? .zero
                self.ringBaseLayer.position = ringBase ?? .zero
                self.littleBaseLayer.position = littleBase ?? .zero

                self.drawBoundingBox(observation: observation)

                self.MarkExtFingers()
            }
        } catch let error as NSError {
            NSLog("Failed to perform HandPoseRequest: %@", error)
        }
    }

    /// Draw the bounding box around the hand
    func drawBoundingBox(observation: VNHumanHandPoseObservation) {

        //Get Bounding box
        // Get all points in the hand
        guard let allPoints = try? observation.recognizedPoints(.all)
        else {
            print(
                "Error getting allPoints in obervation.recognizedPoints(.all)"
            )
            return
        }

        let mappedPoints = allPoints.values.map {
            self.mapToPreviewLayer(point: $0.location)
        }
        guard !mappedPoints.isEmpty else {
            print(
                "Error mapping points to preview layer"
            )
            return
        }

        //Calculate bounding rectangle
        // Extract x coord and y coord from all points.
        let xCoordinates = mappedPoints.compactMap { $0?.x }
        let yCoordinates = mappedPoints.compactMap { $0?.y }

        // Find min and max x and y to create a bounding rectangle
        if let minX = xCoordinates.min(),
            let maxX = xCoordinates.max(),
            let minY = yCoordinates.min(),
            let maxY = yCoordinates.max()
        {
            let boundingRect = CGRect(
                x: minX, y: minY, width: maxX - minX,
                height: maxY - minY)

            // Setup bounding box shape layer
            boundingBoxLayer.path = UIBezierPath(rect: boundingRect).cgPath
        }
    }
    func MarkExtFingers(){
        for finger in Finger.allCases {
                if finger == .thumb {
                    if handPose.extendedFingers[finger] == true {
                        self.thumbTipLayer.fillColor = UIColor.green.withAlphaComponent(0.5).cgColor
                    }
                    else {
                        self.thumbTipLayer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
                    }
                }
                else if finger == .index {
                    if handPose.extendedFingers[finger] == true {
                        self.indexTipLayer.fillColor = UIColor.green.withAlphaComponent(0.5).cgColor
                    }
                    else {
                        self.indexTipLayer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
                    }
                }
                else if finger == .middle {
                    if handPose.extendedFingers[finger] == true {
                        self.middleTipLayer.fillColor = UIColor.green.withAlphaComponent(0.5).cgColor
                    }
                    else {
                        self.middleTipLayer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
                    }
                }
                else if finger == .ring {
                    if handPose.extendedFingers[finger] == true {
                        self.ringTipLayer.fillColor = UIColor.green.withAlphaComponent(0.5).cgColor
                    }
                    else {
                        self.ringTipLayer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
                    }
                }
                else if finger == .little{
                    if handPose.extendedFingers[finger] == true {
                        self.littleTipLayer.fillColor = UIColor.green.withAlphaComponent(0.5).cgColor
                    }
                    else {
                        self.littleTipLayer.fillColor = UIColor.red.withAlphaComponent(0.5).cgColor
                    }
                }
        }
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
            let inputDevice = try self.configureFrontCamera(for: captureSession)
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

    fileprivate func configureFrontCamera(for captureSession: AVCaptureSession)
        throws -> (device: AVCaptureDevice, resolution: CGSize)
    {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video,
            position: .front)

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
        let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")
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

extension ViewController: HandPoseDelegate {
    func fingerCountChanged(count: Int) {
        DispatchQueue.main.async {
            self.countLabel?.text = "\(count)"
        }
    }
}
