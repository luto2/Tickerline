import QtQuick
import qs.modules.common.functions as CF

/**
 * Runs the local `claude` CLI (Claude Code) instead of calling a web API.
 * Uses the CLI's own login, so no API key. One sidebar chat = one Claude session (--resume).
 * Tools follow ~/.claude/settings.json permissions. Denied tool calls show up as a
 * command request in the chat; approving it reruns the turn with that tool allowed.
 */
ApiStrategy {
    property string sessionId: ""
    property list<string> allowedTools: []
    property var request: ({})
    property bool isReasoning: false

    function buildEndpoint(model: AiModel): string { return "" }
    function buildAuthorizationHeader(apiKeyEnvVarName: string): string { return "" }

    function buildRequestData(model: AiModel, messages, systemPrompt: string, temperature: real, tools: list<var>, filePath: string) {
        // The session already holds the history, so only the newest message is sent
        let prompt = messages.length > 0 ? messages[messages.length - 1].rawContent : "";
        if (filePath && filePath.length > 0) prompt += `\n\nAttached file: ${CF.FileUtils.trimFileProtocol(filePath)}`;
        // tools is the permission mode picked in the sidebar (Ai.tools.claude)
        request = { "model": model.model, "mode": typeof tools === "string" ? tools : "default", "prompt": prompt, "systemPrompt": systemPrompt };
        return {};
    }

    // ponytail: replaces the whole curl script; add a buildCommand hook to ApiStrategy if another CLI backend shows up
    function finalizeScriptContent(scriptContent: string): string {
        const q = s => `'${CF.StringUtils.shellSingleQuoteEscape(s)}'`;
        let cmd = `cd ~ && exec claude -p --output-format stream-json --verbose --include-partial-messages --model ${q(request.model)} --permission-mode ${q(request.mode)}`;
        if (sessionId.length > 0) cmd += ` --resume ${q(sessionId)}`;
        if (allowedTools.length > 0) cmd += ` --allowedTools ${allowedTools.map(q).join(" ")}`;
        if (request.systemPrompt?.length > 0) cmd += ` --append-system-prompt ${q(request.systemPrompt)}`;
        cmd += ` -- ${q(request.prompt)}`;
        const missing = "command -v claude >/dev/null || { echo '**Claude Code isn'\\''t installed.** Install it from https://claude.com/claude-code, then run `claude` once in a terminal to log in.'; exit 1; }";
        return `#!/usr/bin/env bash\n${missing}\n${cmd} < /dev/null 2>&1\n`; // no stdin, or the CLI waits 3 s for it and warns
    }

    function append(message, text) {
        message.rawContent += text;
        message.content += text;
    }

    function toolSummary(input) {
        const s = input?.command ?? input?.file_path ?? input?.pattern ?? input?.url ?? input?.query ?? JSON.stringify(input ?? {});
        return s.length > 200 ? s.slice(0, 200) + "…" : s;
    }

    // Permission rule that allows exactly what was denied
    function permissionRule(denial) {
        if (denial.tool_name === "Bash" && denial.tool_input?.command) return `Bash(${denial.tool_input.command})`;
        return denial.tool_name;
    }

    function parseResponseLine(line, message) {
        let data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            append(message, line + "\n"); // CLI errors (not logged in, bad flag) arrive as plain text
            return {};
        }

        if (data.type === "system" && data.subtype === "init") {
            sessionId = data.session_id;
        } else if (data.type === "stream_event" && data.event?.type === "content_block_delta") {
            const delta = data.event.delta;
            if (delta.type === "text_delta" && delta.text.length > 0) {
                if (isReasoning) {
                    isReasoning = false;
                    append(message, "\n\n</think>\n\n");
                }
                append(message, delta.text);
            } else if (delta.type === "thinking_delta" && delta.thinking.length > 0) {
                if (!isReasoning) {
                    isReasoning = true;
                    append(message, "\n\n<think>\n\n");
                }
                append(message, delta.thinking);
            }
        } else if (data.type === "assistant") {
            for (const block of data.message?.content ?? []) {
                if (block.type === "tool_use") append(message, `\n\n> **${block.name}** \`${toolSummary(block.input)}\`\n\n`);
            }
        } else if (data.type === "result") {
            if (isReasoning) {
                isReasoning = false;
                append(message, "\n\n</think>\n\n");
            }
            if (data.is_error && data.result) append(message, `\n\n**Error**: ${data.result}`);
            const denials = data.permission_denials ?? [];
            if (denials.length > 0) {
                const lines = denials.map(d => `${d.tool_name}: ${toolSummary(d.tool_input)}`).join("\n");
                append(message, `\n\n**Permission request**\n\n\`\`\`command\n${lines}\n\`\`\``);
                message.functionName = "claude_permission";
                message.functionCall = { "name": "claude_permission", "args": { "rules": denials.map(permissionRule) } };
                message.functionPending = true;
            }
            const usage = data.usage ?? {};
            const input = (usage.input_tokens ?? 0) + (usage.cache_read_input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0);
            const output = usage.output_tokens ?? 0;
            return { finished: true, tokenUsage: { input: input, output: output, total: input + output } };
        }
        return {};
    }

    function reset() {
        isReasoning = false;
    }

    function clearSession() {
        sessionId = "";
        allowedTools = [];
    }
}
