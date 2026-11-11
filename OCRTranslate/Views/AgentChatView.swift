import SwiftUI
import UIKit

/// 智能体对话页:技能预设切换 + 图片 OCR 输入 + OpenAI 兼容云端模型
struct AgentChatView: View {
    @StateObject private var agentStore = AgentStore.shared
    @ObservedObject private var manager = TranslationManager.shared

    @State private var messages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showSkillEditor = false
    @State private var showPhotoPicker = false
    @State private var pendingImage: UIImage?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                skillBar
                Divider()

                if messages.isEmpty {
                    emptyState
                } else {
                    messageList
                }

                if !errorMessage.isEmpty {
                    errorBanner
                }

                Divider()
                inputBar
            }
            .background(PTBackground())
            .navigationTitle("智能体")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button {
                            messages = []
                            errorMessage = ""
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                        }
                        Button {
                            showSkillEditor = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                    }
                }
            }
            .sheet(isPresented: $showSkillEditor) {
                SkillEditorView()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPicker(image: $pendingImage) {
                    processPendingImage()
                }
            }
        }
    }

    // MARK: - 子视图

    private var skillBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(agentStore.skills) { skill in
                    let isSelected = agentStore.selectedSkillID == skill.id
                    Button {
                        agentStore.selectedSkillID = skill.id
                    } label: {
                        Text(skill.name)
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.ptField)
                            .foregroundColor(isSelected ? .accentColor : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("当前技能:\(agentStore.selectedSkill?.name ?? "无")")
                .font(.headline)
            Text("支持文字对话,或点左下角图片按钮导入截图,\n自动识别图中文字后发送给 AI 处理。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages.indices, id: \.self) { i in
                        bubble(for: messages[i])
                            .id(i)
                    }

                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("生成中…")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                withAnimation {
                    proxy.scrollTo(messages.count - 1, anchor: .bottom)
                }
            }
        }
    }

    private func bubble(for message: ChatMessage) -> some View {
        let isUser = message.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 40) }
            Text(message.content)
                .font(.body)
                .textSelection(.enabled)
                .padding(12)
                .background(isUser ? Color.accentColor.opacity(0.85) : Color.ptField)
                .foregroundColor(isUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isUser { Spacer(minLength: 40) }
        }
    }

    private var errorBanner: some View {
        Text(errorMessage)
            .font(.caption)
            .foregroundColor(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(Color.red.opacity(0.08))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            Button {
                showPhotoPicker = true
            } label: {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(.accentColor)
            }
            .disabled(isLoading)

            TextField("输入消息…", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.send)
                .onSubmit { send() }

            Button {
                send()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(canSend ? .accentColor : Color(.tertiaryLabel))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - 逻辑

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }
        inputText = ""
        errorMessage = ""
        messages.append(ChatMessage(role: "user", content: text))
        Task { await runChat() }
    }

    /// 图片 → OCR 识别 → 文字填入输入框,用户确认后发送
    private func processPendingImage() {
        guard let image = pendingImage, let cgImage = image.cgImage else { return }
        pendingImage = nil
        isLoading = true
        errorMessage = ""

        OCREngine.shared.recognizeText(from: cgImage) { blocks in
            DispatchQueue.main.async {
                isLoading = false
                let text = blocks
                    .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                if text.isEmpty {
                    errorMessage = "图片中未识别到文字"
                } else {
                    inputText = text
                }
            }
        }
    }

    private func runChat() async {
        guard let skill = agentStore.selectedSkill else { return }

        guard !manager.config.apiEndpoint.isEmpty, !manager.config.apiKey.isEmpty else {
            errorMessage = "尚未配置 AI 接口:请到「截图翻译/屏幕翻译」页右上角 ⚙️ 设置 → 翻译引擎选「AI 翻译」,填写 API 地址和 Key"
            return
        }

        isLoading = true
        errorMessage = ""

        // 系统提示词(技能人设)+ 最近 30 条上下文
        var payload = [ChatMessage(role: "system", content: skill.systemPrompt)]
        payload.append(contentsOf: messages.suffix(30))

        let defaultModel = manager.config.aiModel.isEmpty ? "gpt-3.5-turbo" : manager.config.aiModel
        let model = skill.model.isEmpty ? defaultModel : skill.model
        let backend = OpenAICompatBackend(endpoint: manager.config.apiEndpoint, apiKey: manager.config.apiKey)

        do {
            let reply = try await backend.chat(messages: payload, model: model, temperature: 0.7)
            messages.append(ChatMessage(role: "assistant", content: reply))
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - 技能管理

struct SkillEditorView: View {
    @StateObject private var store = AgentStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var editingSkill: AgentSkill?

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(store.skills) { skill in
                        Button {
                            editingSkill = skill
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(skill.name)
                                        .foregroundColor(.primary)
                                    Text(skill.systemPrompt)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .onDelete { store.delete(at: $0) }
                } header: {
                    Text("技能预设(智能体人设)")
                } footer: {
                    Text("每个技能是一段系统提示词,可指定不同模型。回到对话页点顶部胶囊即可切换。左滑可删除。")
                }

                Section {
                    Button {
                        let newSkill = AgentSkill(name: "新技能", systemPrompt: "")
                        store.save(newSkill)
                        editingSkill = newSkill
                    } label: {
                        Label("添加技能", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("技能管理")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .sheet(item: $editingSkill) { skill in
                SkillDetailEditor(skill: skill) { updated in
                    store.save(updated)
                }
            }
        }
    }
}

struct SkillDetailEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var skill: AgentSkill
    var onSave: (AgentSkill) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("技能名称") {
                    TextField("如:日语翻译官", text: $skill.name)
                }
                Section("模型(留空使用设置中的默认模型)") {
                    TextField("如:deepseek-chat", text: $skill.model)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                Section("系统提示词") {
                    TextEditor(text: $skill.systemPrompt)
                        .frame(minHeight: 160)
                        .font(.caption)
                }
            }
            .navigationTitle("编辑技能")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(skill)
                        dismiss()
                    }
                    .disabled(skill.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
