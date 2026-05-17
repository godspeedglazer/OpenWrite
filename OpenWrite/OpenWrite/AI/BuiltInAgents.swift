import Foundation

/// Backward-compatible alias for `AgentRegistry` presets.
enum BuiltInAgents {
    static var defaultAgent: AgentConfig { AgentRegistry.defaultAgent }
    static var all: [AgentConfig] { AgentRegistry.pickerAgents }
    static func agent(id: String) -> AgentConfig { AgentRegistry.agent(id: id) }
    static var researchQA: AgentConfig { AgentRegistry.researchQA }
    static var summarizeSelection: AgentConfig { AgentRegistry.noteSummarizer }
    static var refineProse: AgentConfig { AgentRegistry.refineProse }
}
