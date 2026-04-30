import SwiftUI

protocol LLMProvider {
    var id: String { get }
    var displayName: String { get }
    var avatarLetter: String { get }
    var avatarColor: Color { get }
    var defaultModel: String { get }
    var binaryName: String { get }

    var passesPromptViaArgument: Bool { get }

    func buildArguments(model: String, systemPrompt: String) -> [String]
    func formatPrompt(_ prompt: String, systemPrompt: String) -> String
}

extension LLMProvider {
    var passesPromptViaArgument: Bool { false }
}

// MARK: - Claude

struct ClaudeProvider: LLMProvider {
    let id = "claude"
    let displayName = "Claude"
    let avatarLetter = "C"
    let avatarColor = Color.orange
    let defaultModel = "sonnet"
    let binaryName = "claude"
    func buildArguments(model: String, systemPrompt: String) -> [String] {
        var args = ["-p", "--no-session-persistence", "--effort", "low"]
        if !model.isEmpty { args += ["--model", model] }
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sp.isEmpty { args += ["--system-prompt", sp] }
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        prompt
    }
}

// MARK: - Codex

struct CodexProvider: LLMProvider {
    let id = "codex"
    let displayName = "Codex"
    let avatarLetter = "X"
    let avatarColor = Color.green
    let defaultModel = "gpt-5.4"
    let binaryName = "codex"

    func buildArguments(model: String, systemPrompt: String) -> [String] {
        var args = ["exec", "--skip-git-repo-check", "--ephemeral", "-c", "model_reasoning_effort=\"low\""]
        if !model.isEmpty { args += ["-m", model] }
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if sp.isEmpty { return prompt }
        return "System instructions: \(sp)\n\n\(prompt)"
    }
}

// MARK: - Gemini

struct GeminiProvider: LLMProvider {
    let id = "gemini"
    let displayName = "Gemini"
    let avatarLetter = "G"
    let avatarColor = Color.blue
    let defaultModel = "gemini-2.5-flash"
    let binaryName = "gemini"

    func buildArguments(model: String, systemPrompt: String) -> [String] {
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var args = [String]()
        if !sp.isEmpty { args += ["-p", sp] }
        // Dummy allowlist name disables all MCP servers — translation doesn't need them,
        // and any MCP connection failure would pollute stdout with warnings.
        args += ["--output-format", "text", "--allowed-mcp-server-names", "foobarbaz"]
        if !model.isEmpty { args += ["-m", model] }
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        prompt
    }
}

// MARK: - LM Studio

struct LMStudioProvider: LLMProvider {
    let id = "lmstudio"
    let displayName = "LM Studio"
    let avatarLetter = "L"
    let avatarColor = Color.purple
    let binaryName = "lms"
    // Empty default — `lms chat` falls back to the currently loaded model.
    let defaultModel = ""
    let passesPromptViaArgument = true

    func buildArguments(model: String, systemPrompt: String) -> [String] {
        var args = ["chat"]
        if !model.isEmpty { args.append(model) }
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sp.isEmpty { args += ["-s", sp] }
        args += ["--dont-fetch-catalog", "-y", "-p"]
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        prompt
    }
}

// MARK: - Apfel

struct ApfelProvider: LLMProvider {
    let id = "apfel"
    let displayName = "Apfel"
    let avatarLetter = "A"
    let avatarColor = Color.red
    let defaultModel = ""
    let binaryName = "apfel"
    let passesPromptViaArgument = true

    func buildArguments(model: String, systemPrompt: String) -> [String] {
        var args = [String]()
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !sp.isEmpty { args += ["-s", sp] }
        args += ["-o", "plain", "--permissive"]
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        prompt
    }
}

// MARK: - Copilot

struct CopilotProvider: LLMProvider {
    let id = "copilot"
    let displayName = "Copilot"
    let avatarLetter = "P"
    let avatarColor = Color.gray
    let defaultModel = "claude-haiku-4.5"
    let binaryName = "copilot"

    func buildArguments(model: String, systemPrompt: String) -> [String] {
        var args = ["-s", "--no-custom-instructions", "--disable-builtin-mcps", "--output-format", "text"]
        if !model.isEmpty { args += ["--model", model] }
        return args
    }

    func formatPrompt(_ prompt: String, systemPrompt: String) -> String {
        let sp = systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if sp.isEmpty { return prompt }
        return "System instructions: \(sp)\n\n\(prompt)"
    }
}

// MARK: - Registry

enum LLMProviderRegistry {
    static let all: [LLMProvider] = [ClaudeProvider(), CodexProvider(), GeminiProvider(), LMStudioProvider(), ApfelProvider(), CopilotProvider()]

    static func provider(forId id: String) -> LLMProvider {
        all.first { $0.id == id } ?? all[0]
    }
}
