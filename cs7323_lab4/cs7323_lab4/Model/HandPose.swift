//
//  HandPose.swift
//  cs7323_lab4
//
//  Created by Ches Smith on 11/3/24.
//

import UIKit
import AVKit
import Vision

// enum for the different fingers to make it easier to access the points
enum Finger: Int, CaseIterable {
    case thumb = 0
    case index = 1
    case middle = 2
    case ring = 3
    case little = 4
}

protocol HandPoseDelegate: AnyObject {
    func fingerCountChanged(count: Int)
}

class HandPose {
    
    weak var delegate: HandPoseDelegate?
    
    private(set) var bases: [Finger: VNRecognizedPoint?] = Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var tips: [Finger: VNRecognizedPoint?] = Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var wrist: VNRecognizedPoint? = nil
    
    private(set) var baseVectors: [Finger: CGPoint?] = Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var tipVectors: [Finger: CGPoint?] = Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, nil) })
    private(set) var extendedFingers: [Finger: Bool] = Dictionary(uniqueKeysWithValues: Finger.allCases.map { ($0, false) })
    
    private(set) var countExtended: Int = 0 {
        // check if value is different from previous value
        didSet {
            if countExtended != oldValue {
                delegate?.fingerCountChanged(count: countExtended)
//                print("Fingers extended: \(countExtended)")
            }
        }
    }
    
    private let confidenceThreshold: Float = 0.5
    private let fingerThresholds: [Finger: Float] = [
        .thumb: 1.4,
        .index: 1.2,
        .middle: 1.2,
        .ring: 1.2,
        .little: 1.2
    ]
    // dictionary from Finger to VNHumanHandPoseObservation.JointsGroupName
    private let fingerMap: [Finger: (group: VNHumanHandPoseObservation.JointsGroupName, tip: VNHumanHandPoseObservation.JointName, base: VNHumanHandPoseObservation.JointName)] = [
        .thumb: (.thumb, .thumbTip, .thumbMP),
        .index: (.indexFinger, .indexTip, .indexMCP),
        .middle: (.middleFinger, .middleTip, .middleMCP),
        .ring: (.ringFinger, .ringTip, .ringMCP),
        .little: (.littleFinger, .littleTip, .littleMCP)
    ]
    
    func updatePose(with observation: VNHumanHandPoseObservation) {
        getPoints(from: observation)
        vectorize()
        checkFingersExtended()
        countExtendedFingers()
    }
    
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
           wristPoint.confidence > confidenceThreshold {
            wrist = wristPoint
        } else {
            wrist = nil
        }
        // get points for each finger
        for finger in Finger.allCases {
            if let fingerPoints = try? observation.recognizedPoints(fingerMap[finger]!.group),
               let tipPoint = fingerPoints[fingerMap[finger]!.tip],
               let basePoint = fingerPoints[fingerMap[finger]!.base],
               tipPoint.confidence > confidenceThreshold, basePoint.confidence > confidenceThreshold {
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
               let tipLocation = tip?.location, let baseLocation = base?.location{
                tipVectors[finger] = CGPoint(x: tipLocation.x - wrist.location.x, y: tipLocation.y - wrist.location.y)
                baseVectors[finger] = CGPoint(x: baseLocation.x - wrist.location.x, y: baseLocation.y - wrist.location.y)
            } else {
                tipVectors[finger] = nil
                baseVectors[finger] = nil
            }
        }
    }
    
    private func isFingerExtended(tipVector: CGPoint?, baseVector: CGPoint?, threshold: Float) -> Bool {
            // Safely unwrap tipVector and baseVector, including their .x and .y properties
            guard let tipVector = tipVector,
                  let baseVector = baseVector,
                  let tipVX = tipVector.x as CGFloat?,
                  let tipVY = tipVector.y as CGFloat?,
                  let baseVX = baseVector.x as CGFloat?,
                  let baseVY = baseVector.y as CGFloat? else {
                return false
            }

            // Calculate the projection
            let projection = Float((tipVX * baseVX + tipVY * baseVY) / (baseVX * baseVX + baseVY * baseVY))
            return projection > threshold
        }

        private func checkFingersExtended() {
            for finger in Finger.allCases {
                // Use optional binding to retrieve vectors and threshold
                if let tipVector = tipVectors[finger],
                   let baseVector = baseVectors[finger],
                   let threshold = fingerThresholds[finger] {
                    
                    // check if finger is extended
                    extendedFingers[finger] = isFingerExtended(tipVector: tipVector, baseVector: baseVector, threshold: threshold)
                    
                } else {
                    // Mark finger as not extended if any component is missing
                    extendedFingers[finger] = false
                }
            }
        }
    
}


