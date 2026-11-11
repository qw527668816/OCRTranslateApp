import SwiftUI

/// 翻译历史:最近 30 条,点开看逐段对照,可左滑删除
struct HistoryView: View {
    @ObservedObject private var manager = TranslationManager.shared

    var body: some View {
        NavigationView {
            Group {
                if manager.history.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("还没有翻译记录")
                            .font(.headline)
                        Text("截图翻译和实时屏幕翻译的结果\n会自动保存在这里(最多 30 条)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(manager.history) { entry in
                            NavigationLink {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text(entry.date.formatted(date: .abbreviated, time: .shortened) + " · " + entry.engine)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        SegmentListView(segments: entry.segments, showBilingual: true)
                                    }
                                    .padding()
                                }
                                .navigationTitle("对照详情")
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.segments.first?.original ?? "")
                                        .font(.subheadline)
                                        .lineLimit(1)
                                    Text(entry.date.formatted(date: .numeric, time: .shortened) + " · " + entry.engine + " · \(entry.segments.count) 段")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { manager.deleteHistory(at: $0) }
                    }
                }
            }
            .navigationTitle("翻译历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清空") {
                        manager.clearHistory()
                    }
                    .disabled(manager.history.isEmpty)
                }
            }
        }
    }
}
