import CoreGraphics
import Foundation

struct OCRRegionConfig: Codable, Equatable {
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat

    static let storageKey = "ocrRegionConfig"
    static let defaultRegion = OCRRegionConfig(x: 0, y: 0, width: 1, height: 1)

    var clamped: OCRRegionConfig {
        let clampedWidth = min(max(width, 0.08), 1)
        let clampedHeight = min(max(height, 0.08), 1)
        let clampedX = min(max(x, 0), 1 - clampedWidth)
        let clampedY = min(max(y, 0), 1 - clampedHeight)
        return OCRRegionConfig(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }

    var summaryText: String {
        let region = clamped
        return "左\(Int(region.x * 100))% 上\(Int(region.y * 100))% 宽\(Int(region.width * 100))% 高\(Int(region.height * 100))%"
    }

    static func load() -> OCRRegionConfig {
        guard let data = defaults.data(forKey: storageKey),
              let region = try? JSONDecoder().decode(OCRRegionConfig.self, from: data) else {
            return defaultRegion
        }
        return region.clamped
    }

    static func save(_ region: OCRRegionConfig) {
        guard let data = try? JSONEncoder().encode(region.clamped) else { return }
        defaults.set(data, forKey: storageKey)
        defaults.synchronize()
    }

    func cropRect(in extent: CGRect) -> CGRect {
        let region = clamped
        let rect = CGRect(
            x: extent.minX + extent.width * region.x,
            y: extent.minY + extent.height * (1 - region.y - region.height),
            width: extent.width * region.width,
            height: extent.height * region.height
        )
        return rect.intersection(extent)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }
}