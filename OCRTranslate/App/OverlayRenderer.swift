import UIKit

/// OCR 识别框(像素坐标,左上原点)
struct OCRBlockBox {
    let index: Int        // 对应译文数组下标
    let text: String      // 原文
    let rect: CGRect      // 在原图上的像素范围
}

/// 原位替换渲染:遮住截图里的原文框,把译文按原位置画回去
/// 实现参考 OnscreenTranslator 的 ScreenshotRenderer(邻居感知遮罩 + 字号双估算)
enum OverlayRenderer {

    static func render(source: UIImage, blocks: [OCRBlockBox], translations: [String]) -> UIImage? {
        guard blocks.count == translations.count, let cg = source.cgImage else { return nil }
        let size = source.size
        let renderer = UIGraphicsImageRenderer(size: size)

        return renderer.image { ctx in
            ctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: size))

            // 按 Y 排序,用于计算每个框向下扩展的"天花板"(下一个邻居的顶部)
            let sorted = blocks.sorted { $0.rect.minY < $1.rect.minY }
            func ceiling(for rect: CGRect) -> CGFloat {
                let next = sorted.first {
                    $0.rect.minY > rect.maxY + 1 &&
                    $0.rect.minX < rect.maxX && $0.rect.maxX > rect.minX
                }
                return next?.rect.minY ?? size.height
            }

            for block in blocks {
                let rect = block.rect
                let translation = translations[block.index]
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                // 目标字号:原框行高 × 0.72 与 单字宽 × 1.6 两个估算取小,再收缩适配译文
                let lineCount = max(1, block.text
                    .split(separator: "\n", omittingEmptySubsequences: false).count)
                let heightFont = (rect.height / CGFloat(lineCount)) * 0.72
                let charsPerLine = max(1, CGFloat(block.text.count) / CGFloat(lineCount))
                let widthFont = (rect.width / charsPerLine) * 1.6
                var fontSize = max(9, min(min(heightFont, widthFont), 50))

                let textWidth = rect.width * 1.18 + 12
                let roomBelow = max(0, ceiling(for: rect) - rect.maxY)
                let maxTextHeight = max(rect.height * 1.8, roomBelow + rect.height - 4)

                // 收缩字号直到译文放得下
                var fittedHeight: CGFloat = 0
                var fittedFont: UIFont = .systemFont(ofSize: fontSize, weight: .medium)
                while fontSize >= 9 {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                        .foregroundColor: UIColor.black
                    ]
                    let bounds = (translation as NSString).boundingRect(
                        with: CGSize(width: textWidth, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        attributes: attrs,
                        context: nil
                    )
                    if bounds.height <= maxTextHeight {
                        fittedHeight = ceil(bounds.height)
                        fittedFont = UIFont.systemFont(ofSize: fontSize, weight: .medium)
                        break
                    }
                    fontSize -= 1
                }

                // 遮罩:覆盖原框,并在译文更高时向下扩展
                let maskWidth = max(rect.width, textWidth) + 8
                let maskHeight = max(rect.height, fittedHeight) + 8
                let maskRect = CGRect(
                    x: rect.minX - 4,
                    y: rect.minY - 3,
                    width: maskWidth,
                    height: maskHeight
                )
                UIColor(white: 1, alpha: 0.94).setFill()
                UIBezierPath(roundedRect: maskRect, cornerRadius: 5).fill()

                // 译文
                if !translation.isEmpty && fittedHeight > 0 {
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: fittedFont,
                        .foregroundColor: UIColor.black
                    ]
                    (translation as NSAttributedString).draw(
                        with: CGRect(x: rect.minX - 1, y: rect.minY + 1, width: textWidth, height: fittedHeight + 4),
                        options: [.usesLineFragmentOrigin, .usesFontLeading],
                        context: nil
                    )
                }
            }
        }
    }
}
