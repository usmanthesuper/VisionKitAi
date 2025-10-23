//
//  VKClassificationPrediction.swift
//  VisionKit
//
//  Created by Maxwell Stone on 6/16/25.
//

import Foundation
import CoreGraphics

public class VKClassificationPrediction: VKPrediction {
    public let className: String
    public let confidence: Float
    public let classId: Int
    
    public init(className: String, confidence: Float, classId: Int) {
        self.className = className
        self.confidence = confidence
        self.classId = classId
    }
    
    public override func getValues() -> [String: Any] {
        let result = [
            "confidence": Double(confidence),
            "class": className,
            "classId": classId
        ] as [String: Any]
        
        return result
    }
}