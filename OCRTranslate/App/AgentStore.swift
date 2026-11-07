import Foundation
import Combine

/// 智能体技能预设:每个技能 = 一段系统提示词(+ 可选模型覆盖)
/// 通过技能切换,同一个 AI 接口即可扮演翻译官/总结器/报错解释等不同"智能体"
struct AgentSkill: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var systemPrompt: String
    /// 留空则使用设置页里配置的默认模型
    var model: String = ""
}

final class AgentStore: ObservableObject {
    static let shared = AgentStore()

    static let defaultSkills: [AgentSkill] = [
        AgentSkill(
            name: "通用助手",
            systemPrompt: "你是一个乐于助人的中文 AI 助手,回答准确、简洁、实用。",
            model: ""
        ),
        AgentSkill(
            name: "翻译官",
            systemPrompt: "你是专业翻译。用户输入中文时译成英文,输入其他语言时译成简体中文。只输出译文,保留原文的段落结构与格式,不要解释。代码、URL、专有名词保持原样。",
            model: ""
        ),
        AgentSkill(
            name: "总结助手",
            systemPrompt: "你是总结专家。用简体中文总结输入内容:先用一句话概括,再分点列出关键信息,尽量保留数字、名称等细节。",
            model: ""
        ),
        AgentSkill(
            name: "报错解释",
            systemPrompt: "你是资深工程师。用户给你报错信息或日志,请用中文回答:1)这个错误的含义;2)可能的原因(按概率排序);3)修复建议。简洁明确。",
            model: ""
        ),
        AgentSkill(
            name: "中文润色",
            systemPrompt: "你是中文编辑。润色用户输入的文字,使其通顺、专业,保持原意与格式,只输出润色后的文本。",
            model: ""
        )
    ]

    @Published var skills: [AgentSkill] = [] {
        didSet { persistSkills() }
    }
    @Published var selectedSkillID: UUID? {
        didSet { persistSelection() }
    }

    private let skillsKey = "agentSkills"
    private let selectedKey = "agentSelectedSkillID"
    private let defaults = UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard

    private init() {
        if let data = defaults.data(forKey: skillsKey),
           let saved = try? JSONDecoder().decode([AgentSkill].self, from: data),
           !saved.isEmpty {
            skills = saved
        } else {
            skills = Self.defaultSkills
        }

        if let raw = defaults.string(forKey: selectedKey),
           let id = UUID(uuidString: raw),
           skills.contains(where: { $0.id == id }) {
            selectedSkillID = id
        } else {
            selectedSkillID = skills.first?.id
        }
    }

    var selectedSkill: AgentSkill? {
        skills.first { $0.id == selectedSkillID } ?? skills.first
    }

    func save(_ skill: AgentSkill) {
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index] = skill
        } else {
            skills.append(skill)
        }
    }

    func delete(at offsets: IndexSet) {
        skills.remove(atOffsets: offsets)
        if let selected = selectedSkillID, !skills.contains(where: { $0.id == selected }) {
            selectedSkillID = skills.first?.id
        }
    }

    private func persistSkills() {
        if let data = try? JSONEncoder().encode(skills) {
            defaults.set(data, forKey: skillsKey)
        }
    }

    private func persistSelection() {
        defaults.set(selectedSkillID?.uuidString, forKey: selectedKey)
    }
}
