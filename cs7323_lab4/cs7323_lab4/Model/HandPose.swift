//
//  HandPose.swift
//  cs7323_lab4
//
//  Created by Ches Smith on 11/3/24.
//

import AVKit
import UIKit
import Vision

// enum for the different fingers to make it easier to access the points
enum Finger: Int, CaseIterable {
    case thumb = 0
    case index = 1
    case middle = 2
    case ring = 3
    case little = 4
}

/// Protocol for the HandPoseDelegate to notify when the number of extended fingers changes
protocol HandPoseDelegate: AnyObject {
    func fingerCountChanged(count: Int)
}

class HandPose {

    weak var delegate: HandPoseDelegate?

    /// raw points from the hand pose observation
    private(set) var bases: [Finger: VNRecognizedPoint?] = Dictionary(
        uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var tips: [Finger: VNRecognizedPoint?] = Dictionary(
        uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var wrist: VNRecognizedPoint? = nil

    /// vetorized points from the hand pose observation
    private(set) var baseVectors: [Finger: CGPoint?] = Dictionary(
        uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var tipVectors: [Finger: CGPoint?] = Dictionary(
        uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var extendedFingers: [Finger: Bool] = Dictionary(
        uniqueKeysWithValues: Finger.allCases.map { ($0, false) })

    /// number of fingers extended
    private(set) var countExtended: Int = 0 {
        // check if value is different from previous value
        didSet {
            if countExtended != oldValue {
                delegate?.fingerCountChanged(count: countExtended)
                //                print("Fingers extended: \(countExtended)")
            }
        }
    }

    // threshold for confidence of points
    private let confidenceThreshold: Float = 0.5
    // threshold for determining if a finger is extended
    private let fingerThresholds: [Finger: Float] = [
        .thumb: 1.3,
        .index: 1.3,
        .middle: 1.3,
        .ring: 1.3,
        .little: 1.3,
    ]
    // dictionary to map finger to joints and joint group
    private let fingerMap:
        [Finger: (
            group: VNHumanHandPoseObservation.JointsGroupName,
            tip: VNHumanHandPoseObservation.JointName,
            base: VNHumanHandPoseObservation.JointName
        )] = [
            .thumb: (.thumb, .thumbTip, .thumbMP),
            .index: (.indexFinger, .indexTip, .indexMCP),
            .middle: (.middleFinger, .middleTip, .middleMCP),
            .ring: (.ringFinger, .ringTip, .ringMCP),
            .little: (.littleFinger, .littleTip, .littleMCP),
        ]

    /// Updates the pose with the given observation
    func updatePose(with observation: VNHumanHandPoseObservation) {
        getPoints(from: observation)
        vectorize()
        checkFingersExtended()
        countExtendedFingers()
    }

    /// Clears the pose when the hand is not detected
    func clear() {
        for finger in Finger.allCases {
            bases[finger] = nil
            tips[finger] = nil
            baseVectors[finger] = nil
            tipVectors[finger] = nil
            extendedFingers[finger] = false
        }
        wrist = nil
        countExtended = 0
    }

    private func countExtendedFingers() {
        countExtended = extendedFingers.values.filter { $0 }.count
    }

    private func getPoints(from observation: VNHumanHandPoseObservation) {
        // get point for wrist
        if let wristPoint = try? observation.recognizedPoint(.wrist),
            wristPoint.confidence > confidenceThreshold
        {
            wrist = wristPoint
        } else {
            wrist = nil
        }
        // get points for each finger
        for finger in Finger.allCases {
            if let fingerPoints = try? observation.recognizedPoints(
                fingerMap[finger]!.group),
                let tipPoint = fingerPoints[fingerMap[finger]!.tip],
                let basePoint = fingerPoints[fingerMap[finger]!.base],
                tipPoint.confidence > confidenceThreshold,
                basePoint.confidence > confidenceThreshold
            {
                tips[finger] = tipPoint
                bases[finger] = basePoint
            } else {
                tips[finger] = nil
                bases[finger] = nil
            }

        }
    }

    private func vectorize() {
        guard let wrist = wrist else {
            return
        }
        for finger in Finger.allCases {
            if let tip = tips[finger], let base = bases[finger],
                let tipLocation = tip?.location,
                let baseLocation = base?.location
            {
                // vector from wrist to tip of finger
                tipVectors[finger] = CGPoint(
                    x: tipLocation.x - wrist.location.x,
                    y: tipLocation.y - wrist.location.y)
                // vector from wrist to base of finger
                baseVectors[finger] = CGPoint(
                    x: baseLocation.x - wrist.location.x,
                    y: baseLocation.y - wrist.location.y)
            } else {
                tipVectors[finger] = nil
                baseVectors[finger] = nil
            }
        }
    }

    private func isFingerExtended(
        tipVector: CGPoint?, baseVector: CGPoint?, threshold: Float
    ) -> Bool {
        // Safely unwrap tipVector and baseVector, including their .x and .y properties
        guard let tipVector = tipVector,
            let baseVector = baseVector,
            let tipVX = tipVector.x as CGFloat?,
            let tipVY = tipVector.y as CGFloat?,
            let baseVX = baseVector.x as CGFloat?,
            let baseVY = baseVector.y as CGFloat?
        else {
            return false
        }

        // Calculate the projection
        let projection = Float(
            (tipVX * baseVX + tipVY * baseVY)
                / (baseVX * baseVX + baseVY * baseVY))
        // if the projection is greater than the threshold, assume the finger is extended
        return projection > threshold
    }

    private func checkFingersExtended() {
        for finger in Finger.allCases {
            // retrieve vectors and threshold
            if let tipVector = tipVectors[finger],
                let baseVector = baseVectors[finger],
                let threshold = fingerThresholds[finger]
            {

                // check if finger is extended
                // different for thumb
                if finger == .thumb {
                    let isExtended = isFingerExtended(
                        tipVector: tipVector, baseVector: baseVector,
                        threshold: threshold)
                    // for the thumb, make sure the tip is farther from the index base than from the thumb base
                    // reduces false positives
                    if let indexBase = baseVectors[.index] {
                        // calculate distance between thumb tip and index base
                        let thumbTipIndexBaseDistance = sqrt(
                            powf(Float(tipVector!.x - indexBase!.x), 2)
                                + powf(Float(tipVector!.y - indexBase!.y), 2))
                        // calculate distance between thumb tip and thumb base
                        let thumbTipBaseDistance = sqrt(
                            powf(Float(tipVector!.x - baseVector!.x), 2)
                                + powf(Float(tipVector!.y - baseVector!.y), 2))
                        // set thumb as extended if the tip is farther from the thumb base
                        // and the thumb is presumed to be extended
                        extendedFingers[finger] =
                            isExtended
                            && thumbTipIndexBaseDistance > thumbTipBaseDistance
                    } else {
                        // if the index base is not detected, just use the original method
                        extendedFingers[finger] = isExtended
                    }
                } else {
                    // for all other fingers, just use the isFingerExtended method
                    extendedFingers[finger] = isFingerExtended(
                        tipVector: tipVector, baseVector: baseVector,
                        threshold: threshold)
                }

            } else {
                // Mark finger as not extended if any component is missing
                extendedFingers[finger] = false
            }
        }
    }

}
