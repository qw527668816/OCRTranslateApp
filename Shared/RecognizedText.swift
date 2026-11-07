import Foundation
import CoreGraphics

struct RecognizedTextBlock: Equatable {
    let text: String
    let confidence: Float
    let boundingBox: CGRect
    
    static func == (lhs: RecognizedTextBlock, rhs: RecognizedTextBlock) -> Bool {
        lhs.text == rhs.text
    }
}

struct OCRFrame: Equatable {
    let blocks: [RecognizedTextBlock]
    let timestamp: Date
    
    var fullText: String {
        blocks.map { $0.text }.joined(separator: "\n")
    }
    
    static func == (lhs: OCRFrame, rhs: OCRFrame) -> Bool {
        lhs.fullText == rhs.fullText
    }
}
