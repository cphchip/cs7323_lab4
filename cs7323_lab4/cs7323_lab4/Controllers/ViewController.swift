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

    // Label to show the number of fingers extended
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
    private var fingerTipLayers: [CAShapeLayer] = (0..<5).map { _ in
        CAShapeLayer()
    }
    private var wristLayer: CAShapeLayer = CAShapeLayer()
    private var fingerBaseLayers: [CAShapeLayer] = (0..<5).map { _ in
        CAShapeLayer()
    }

    private var boundingBoxLayer = CAShapeLayer()

    // MARK: UIViewController overrides

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up HandPose delegate to receive updates
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
        setupFingerLayers()

        //Setup Bounding Box Layer
        setupBoundingBoxLayer()
    }

    // setup a layer for a finger tips
    private func setupLayer(layer: CAShapeLayer, fill: CGColor) {
        layer.fillColor = fill
        layer.strokeColor = UIColor.clear.cgColor
        layer.bounds = CGRect(x: 0, y: 0, width: 14, height: 14)  // Circle size
        layer.cornerRadius = 7  // Half of the width/height for a circle
        layer.path = UIBezierPath(ovalIn: layer.bounds).cgPath
        previewView?.layer.addSublayer(layer)
    }

    // setup the layers for the finger tips (keep the layers and move the layers instead of redrawing)
    private func setupFingerLayers() {
        // Configure layers for finger tips
        setupLayer(
            layer: wristLayer,
            fill: UIColor.yellow.withAlphaComponent(0.5).cgColor)

        fingerTipLayers.forEach { layer in
            setupLayer(
                layer: layer, fill: UIColor.red.withAlphaComponent(0.5).cgColor)
        }

        fingerBaseLayers.forEach { layer in
            setupLayer(
                layer: layer, fill: UIColor.blue.withAlphaComponent(0.5).cgColor
            )
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
        // coordinates may need to be flipped or reversed depending on orientation
        // the orientation is locked to portrait to make this simpler
        let newPoint = CGPoint(x: 1 - point.x, y: 1 - point.y)
        let convertedPoint = previewLayer.layerPointConverted(
            fromCaptureDevicePoint: newPoint)
        return convertedPoint
    }

    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    /// - Tag: PerformRequests
    // Handle delegate method callback on receiving a sample buffer.
    // This is where we get the pixel buffer from the camera and need to
    // generate the vision requests
    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
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

        self.performDetection(
            pixelBuffer: pixelBuffer,
            exifOrientation: exifOrientation,
            requestHandlerOptions: requestHandlerOptions)
    }

    // functionality to run the image detection on pixel buffer
    // This is an involved computation, so beware of running too often
    func performDetection(
        pixelBuffer: CVPixelBuffer,
        exifOrientation: CGImagePropertyOrientation,
        requestHandlerOptions: [VNImageOption: AnyObject]
    ) {

        // create request
        let imageRequestHandler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: exifOrientation,
            options: requestHandlerOptions)

        do {
            try imageRequestHandler.perform([handPoseRequest])
            if let observation = handPoseRequest.results?.first {

                // start hand pose update
                self.handPose.updatePose(with: observation)
                self.drawBoundingBox(observation: observation)

            } else {
                handPose.clear()
                clearBoundingBox()
            }
            self.drawFingerPoints()
        } catch let error as NSError {
            NSLog("Failed to perform HandPoseRequest: %@", error)
        }
    }

    private func drawFingerPoints() {
        DispatchQueue.main.async {
            // loop over all the fingers and draw the points
            for finger in Finger.allCases {
                // draw the finger tips
                if let fingerTipPoint = self.handPose.tips[finger],
                    let fingerTipLocation = fingerTipPoint?.location
                {
                    self.fingerTipLayers[finger.rawValue].position =
                        self.mapToPreviewLayer(point: fingerTipLocation)
                        ?? .zero
                } else {
                    self.fingerTipLayers[finger.rawValue].position = .zero
                }
                // draw the finger bases
                if let fingerBasePoint = self.handPose.bases[finger],
                    let fingerBaseLocation = fingerBasePoint?.location
                {
                    self.fingerBaseLayers[finger.rawValue].position =
                        self.mapToPreviewLayer(point: fingerBaseLocation)
                        ?? .zero
                } else {
                    self.fingerBaseLayers[finger.rawValue].position = .zero
                }

            }

            // draw the wrist point
            if let wristPoint = self.handPose.wrist {
                self.wristLayer.position =
                    self.mapToPreviewLayer(point: wristPoint.location)
                    ?? .zero
            } else {
                self.wristLayer.position = .zero
            }
            self.MarkExtFingers()
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
            let xPadding = 0.1 * (maxX - minX)
            let yPadding = 0.1 * (maxY - minY)
            let boundingRect = CGRect(
                x: minX - xPadding, y: minY - yPadding,
                width: maxX - minX + 2 * xPadding,
                height: maxY - minY + 2 * yPadding)
            DispatchQueue.main.async {
                // Setup bounding box shape layer
                self.boundingBoxLayer.path =
                    UIBezierPath(rect: boundingRect).cgPath
            }
        }
    }

    // Clear the bounding box when no hand is detected
    private func clearBoundingBox() {
        DispatchQueue.main.async {
            self.boundingBoxLayer.path = nil
        }
    }

    // update the colors of the finger tip layers based on the extended fingers
    func MarkExtFingers() {
        // loop over all fingers and update the color based on if they are extended
        for finger in Finger.allCases {
            
            if handPose.extendedFingers[finger] ?? false {
                // set the fill color to green if the finger is extended
                fingerTipLayers[finger.rawValue].fillColor =
                    UIColor.green.withAlphaComponent(0.5).cgColor
            } else {
                // set the fill color to red if the finger is not extended
                fingerTipLayers[finger.rawValue].fillColor =
                    UIColor.red.withAlphaComponent(0.5).cgColor
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
        
        // making this static simplifies the mapping of vision points to the screen
        return .upMirrored

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
    /// - Tag: FingerCountChanged
    /// Delegate method for HandPose to update the UI with the number of fingers extended
    func fingerCountChanged(count: Int) {
        DispatchQueue.main.async {
            self.countLabel?.text = "\(count)"
        }
    }
}
