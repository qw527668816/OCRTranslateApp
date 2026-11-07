import SwiftUI

struct OCRRegionEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var region: OCRRegionConfig
    @State private var draftRegion: OCRRegionConfig
    @State private var dragStartRegion: OCRRegionConfig?
    @State private var resizeStartRegion: OCRRegionConfig?

    init(region: Binding<OCRRegionConfig>) {
        _region = region
        _draftRegion = State(initialValue: region.wrappedValue.clamped)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                Text("拖动蓝色区域选择 OCR 识别范围，拖动右下角圆点调整大小。")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { proxy in
                    ZStack(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemBackground))
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(Color.secondary.opacity(0.35), lineWidth: 1)
                            )

                        gridLines
                        regionMask(in: proxy.size)
                        regionFrame(in: proxy.size)
                    }
                    .contentShape(Rectangle())
                }
                .aspectRatio(9.0 / 19.5, contentMode: .fit)
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 8) {
                    Text("当前区域")
                        .font(.headline)
                    Text(draftRegion.summaryText)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button("恢复全屏识别") {
                    draftRegion = .defaultRegion
                    saveDraft()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .navigationTitle("识别区域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveDraft()
                        dismiss()
                    }
                }
            }
        }
    }

    private var gridLines: some View {
        GeometryReader { proxy in
            Path { path in
                let width = proxy.size.width
                let height = proxy.size.height
                for index in 1..<3 {
                    let x = width * CGFloat(index) / 3
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: height))

                    let y = height * CGFloat(index) / 3
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: width, y: y))
                }
            }
            .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
    }

    private func regionMask(in size: CGSize) -> some View {
        let rect = displayRect(in: size)

        return ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.35))

            RoundedRectangle(cornerRadius: 12)
                .fill(Color.clear)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
    }

    private func regionFrame(in size: CGSize) -> some View {
        let rect = displayRect(in: size)

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 3)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.accentColor.opacity(0.18))
                )
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(moveGesture(in: size))

            Circle()
                .fill(Color.accentColor)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(Color.white, lineWidth: 3))
                .position(x: rect.maxX, y: rect.maxY)
                .gesture(resizeGesture(in: size))
        }
    }

    private func displayRect(in size: CGSize) -> CGRect {
        let region = draftRegion.clamped
        return CGRect(
            x: size.width * region.x,
            y: size.height * region.y,
            width: size.width * region.width,
            height: size.height * region.height
        )
    }

    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if dragStartRegion == nil {
                    dragStartRegion = draftRegion.clamped
                }
                guard let start = dragStartRegion else { return }
                draftRegion = OCRRegionConfig(
                    x: start.x + value.translation.width / max(size.width, 1),
                    y: start.y + value.translation.height / max(size.height, 1),
                    width: start.width,
                    height: start.height
                ).clamped
            }
            .onEnded { _ in
                dragStartRegion = nil
                saveDraft()
            }
    }

    private func resizeGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if resizeStartRegion == nil {
                    resizeStartRegion = draftRegion.clamped
                }
                guard let start = resizeStartRegion else { return }
                draftRegion = OCRRegionConfig(
                    x: start.x,
                    y: start.y,
                    width: start.width + value.translation.width / max(size.width, 1),
                    height: start.height + value.translation.height / max(size.height, 1)
                ).clamped
            }
            .onEnded { _ in
                resizeStartRegion = nil
                saveDraft()
            }
    }

    private func saveDraft() {
        let clamped = draftRegion.clamped
        draftRegion = clamped
        region = clamped
        OCRRegionConfig.save(clamped)
    }
}

struct OCRRegionEditorView_Previews: PreviewProvider {
    static var previews: some View {
        OCRRegionEditorView(region: .constant(.defaultRegion))
    }
}