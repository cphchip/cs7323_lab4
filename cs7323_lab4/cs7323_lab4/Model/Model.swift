/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains the main app implementation using Vision.
*/

import UIKit
import Vision

class VisionModel {
    
    static let sharedInstance = VisionModel()  // define shared instance of the Vision model

    // Vision requests
    private var detectionRequests: [VNDetectHumanHandPoseRequest]?
    private var trackingRequests: [VNTrackObjectRequest]?
    lazy var sequenceRequestHandler = VNSequenceRequestHandler()


    // MARK: Performing Vision Requests

    /// - Tag: WriteCompletionHandler
    fileprivate func prepareVisionRequest() {

        self.trackingRequests = []

        // create a detection request that processes an image and returns hand poses
        // completion handler does not run immediately, it is run
        // after a hand pose is detected
        let handPoseDetectionRequest: VNDetectHumanHandPoseRequest =
            VNDetectHumanHandPoseRequest(
                completionHandler: self.handPoseDetectionCompletionHandler)

        // Save this detection request for later processing
        self.detectionRequests = [handPoseDetectionRequest]

        // setup the tracking of a sequence of features from detection
        self.sequenceRequestHandler = VNSequenceRequestHandler()
    }


}

