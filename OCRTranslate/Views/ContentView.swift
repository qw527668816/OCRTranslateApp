import ReplayKit
import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var broadcastMonitor = BroadcastMonitor.shared
    @StateObject private var translationManager = TranslationManager.shared
    @ObservedObject private var pip = PiPOverlay.shared
    @State private var showSettings = false
    @State private var showHistory = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    broadcastButton

                    if let result = broadcastMonitor.latestResult {
                        translationCard(result)
                    }

                    instructionsCard
                }
                .padding()
            }
            .background(PTBackground())
            .navigationTitle("屏幕翻译")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showHistory) {
                HistoryView()
            }
        }
    }

    private var statusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Circle()
                    .fill(broadcastMonitor.isBroadcasting ? Color.green : Color.gray)
                    .frame(width: 12, height: 12)

                Text(broadcastMonitor.isBroadcasting ? "正在翻译中" : "等待启动")
                    .font(.headline)
                    .foregroundColor(.ptText)

                Spacer()

                Text(currentEngineName)
                    .font(.caption)
                    .foregroundColor(.ptSub)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.ptField))
            }

            if let lastUpdate = broadcastMonitor.lastUpdateTime {
                Text("上次更新: \(lastUpdate, style: .relative)前")
                    .font(.caption)
                    .foregroundColor(.ptSub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ptCard()
    }

    private var broadcastButton: some View {
        ZStack {
            if broadcastMonitor.isBroadcasting {
                Button {
                    haptic()
                    broadcastMonitor.sendStopCommand()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                        Text("停止翻译")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.ptDanger)
                    )
                    .foregroundColor(.white)
                }
            } else {
                ZStack {
                    BroadcastPickerView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)

                    HStack(spacing: 10) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                        Text("开始屏幕翻译")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(LinearGradient(colors: [.ptAccent, .ptAccent2], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                    .foregroundColor(.white)
                    .shadow(color: Color.ptAccent2.opacity(0.38), radius: 12, y: 6)
                    .allowsHitTesting(false)
                }
                .frame(height: 56)
            }
        }
    }

    /// 实时结果:逐段原文-译文对照
    private func translationCard(_ result: TranslateResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("最新识别结果")
                    .font(.caption)
                    .foregroundColor(.ptSub)
                Spacer()
                Text("共 \(result.segments.count) 段")
                    .font(.caption2)
                    .foregroundColor(.ptSub)
            }

            VStack(alignment: .leading, spacing: 12) {
                SegmentListView(
                    segments: result.segments,
                    showBilingual: translationManager.config.showBilingual
                )
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.ptField)
            )

            Button {
                haptic()
                if pip.isActive {
                    pip.stop()
                } else {
                    pip.show(segments: result.segments, bilingual: translationManager.config.showBilingual)
                }
            } label: {
                Label(
                    pip.isActive ? "停止悬浮窗" : "画中画悬浮(任意 App 上方)",
                    systemImage: pip.isActive ? "pip.exit" : "pip.enter"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(pip.isActive ? Color.ptDanger : Color.ptField)
                )
                .foregroundColor(pip.isActive ? .white : .ptText)
            }

            if !pip.statusText.isEmpty {
                Text(pip.statusText)
                    .font(.caption)
                    .foregroundColor(.ptSub)
            }
        }
        .ptCard()
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("使用说明")
                .font(.headline)
                .foregroundColor(.ptText)

            instructionRow(icon: "1.circle.fill", text: "点击「开始屏幕翻译」按钮")
            instructionRow(icon: "2.circle.fill", text: "在系统菜单中选择 ScreenTranslator 并点击「开始直播」")
            instructionRow(icon: "3.circle.fill", text: "切换到需要翻译的应用,结果将逐段对照显示")
            instructionRow(icon: "4.circle.fill", text: "识别区域可在设置中拖拽调整")
            instructionRow(icon: "5.circle.fill", text: "停止翻译时点击按钮(系统红条也可停止)")
        }
        .ptCard()
    }

    private func instructionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.ptAccent)
                .font(.body)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.ptSub)
        }
    }

    private var currentEngineName: String {
        translationManager.config.engineType.displayName
    }
}

// MARK: - Broadcast Picker

private struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 300, height: 56))
        picker.preferredExtension = AppConfig.extensionBundleID
        picker.showsMicrophoneButton = false
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
