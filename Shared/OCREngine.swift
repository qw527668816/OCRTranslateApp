import Foundation
import Vision
import CoreImage
import UIKit

class OCREngine {
    static let shared = OCREngine()
    
    private init() {}
    
    /// Recognize text from a CGImage using Apple Vision
    func recognizeText(from image: CGImage, completion: @escaping ([RecognizedTextBlock]) -> Void) {
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion([])
                return
            }
            
            let blocks: [RecognizedTextBlock] = observations.compactMap { obs in
                guard let topCandidate = obs.topCandidates(1).first else { return nil }
                return RecognizedTextBlock(
                    text: topCandidate.string,
                    confidence: topCandidate.confidence,
                    boundingBox: obs.boundingBox
                )
            }
            completion(blocks)
        }
        
        // Configuration for best accuracy
        request.recognitionLevel = .accurate
        request.recognitionLanguages = [
            "en-US", "zh-Hans", "zh-Hant", "ja", "ko",
            "fr-FR", "de-DE", "es-ES", "pt-BR", "ru",
            "ar-SA", "th", "vi", "it", "nl", "pl", "tr"
        ]
        request.usesLanguageCorrection = true
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("[OCR] Vision error: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    /// Detect if OCR content has meaningfully changed compared to previous frame
    func hasContentChanged(old: OCRFrame?, new: OCRFrame, threshold: Float = 0.15) -> Bool {
        guard let old = old else { return !new.blocks.isEmpty }
        
        let oldTexts = Set(old.blocks.map { $0.text })
        let newTexts = Set(new.blocks.map { $0.text })
        
        let intersection = oldTexts.intersection(newTexts)
        let union = oldTexts.union(newTexts)
        
        guard !union.isEmpty else { return false }
        
        let similarity = Float(intersection.count) / Float(union.count)
        return similarity < (1.0 - threshold)
    }
}
