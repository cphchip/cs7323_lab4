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
    

//    // define behavior for when we detect a hand pose
    func handPoseDetectionCompletionHandler(request: VNRequest, error: Error?) {
        // any errors? If yes, show and try to keep going
        if error != nil {
            print("HandPoseDetection error: \(String(describing: error)).")
        }

        // see if we can get any hand pose features, this will fail if no hand pose detected
        // try to save the hand pose observations to a results vector
        guard
            let handPoseDetectionRequest = request
                as? VNDetectHumanHandPoseRequest,
            let results = handPoseDetectionRequest.results
        else {
            return
        }

        if !results.isEmpty {
            print("Initial Hand Pose found... setting up tracking.")

        }

        // if we got here, then a face was detected and we have its features saved
        // The above hand pose detection was the most computational part of what we did
        // the remaining tracking only needs the results vector of hand features
        // so we can process it in the main queue (because we will us it to update UI)
 //       DispatchQueue.main.async {
 //           // Add the face features to the tracking list
 //           for observation in results {
 //               let handPoseTrackingRequest = VNTrackObjectRequest(
 //                   detectedObjectObservation: observation)
 //               // the array starts empty, but this will constantly add to it
 //               // since on the main queue, there are no race conditions
 //               // everything is from a single thread
 //               // once we add this, it kicks off tracking in another function
 //               self.trackingRequests?.append(handPoseTrackingRequest)

//                // NOTE: if the initial hand pose detection is actually not a hand,
//                // then the app will continually mess up trying to perform tracking
//            }
//        }

    }

}

