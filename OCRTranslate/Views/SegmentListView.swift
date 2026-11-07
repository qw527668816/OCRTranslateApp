import SwiftUI
import UIKit

/// 原文-译文对照列表
/// 对照模式下每段先显示灰色小字原文,再显示译文;点击复制按钮可复制"原文+译文"
struct SegmentListView: View {
    let segments: [SegmentPair]
    var showBilingual: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(segments.indices, id: \.self) { i in
                let pair = segments[i]
                VStack(alignment: .leading, spacing: 4) {
                    if showBilingual && !pair.original.isEmpty {
                        Text(pair.original)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack(alignment: .top, spacing: 8) {
                        Text(pair.translated)
                            .font(.body)
                            .textSelection(.enabled)

                        Spacer(minLength: 8)

                        Button {
                            UIPasteboard.general.string = showBilingual && !pair.original.isEmpty
                                ? "\(pair.original)\n\(pair.translated)"
                                : pair.translated
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                if i < segments.count - 1 {
                    Divider()
                }
            }

            Button {
                copyAll()
            } label: {
                Label("复制全部", systemImage: "doc.on.doc.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(.top, 2)
        }
    }

    private func copyAll() {
        let text = segments
            .map { showBilingual && !$0.original.isEmpty ? "\($0.original)\n\($0.translated)" : $0.translated }
            .joined(separator: "\n\n")
        UIPasteboard.general.string = text
    }
}
