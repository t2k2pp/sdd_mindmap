## Skills
A skill is a set of local instructions to follow that is stored in a `SKILL.md` file. Below is the list of skills that can be used. Each entry includes a name, description, and file path so you can open the source for full instructions when using a specific skill.

### Available skills
- skill-fetcher: Agent Registryからスキル・サブエージェント・ワークフロー・チェックリストを取得するブートストラップスキル。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/skill-fetcher/SKILL.md)
- ai-development-guidelines: AI駆動開発の禁止事項、よくある問題と対策（全FW共通）。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/ai-development-guidelines/SKILL.md)
- mobile-ux: タッチインタラクション、画面設計などモバイル開発共通のUX指針。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/mobile-ux/SKILL.md)
- mobile-app-design: モバイルアプリの設計原則。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/mobile-app-design/SKILL.md)
- flutter-development: Riverpod、GoRouter、UIコンポーネント実装を含むFlutter開発スキル。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/flutter-development/SKILL.md)
- flutter-environment-check: Flutter Doctor、SDK互換性確認など環境診断スキル。 (file: /Users/osia/Documents/GenAIWork/sdd_mindmap/.agent/skills/flutter-environment-check/SKILL.md)

### How to use skills
- Discovery: The list above is the skills available in this session (name + description + file path). Skill bodies live on disk at the listed paths.
- Trigger rules: If the user names a skill (with `$SkillName` or plain text) OR the task clearly matches a skill's description shown above, you must use that skill for that turn. Multiple mentions mean use them all. Do not carry skills across turns unless re-mentioned.
- Missing/blocked: If a named skill isn't in the list or the path can't be read, say so briefly and continue with the best fallback.
- How to use a skill (progressive disclosure):
  1) After deciding to use a skill, open its `SKILL.md`. Read only enough to follow the workflow.
  2) When `SKILL.md` references relative paths (e.g., `scripts/foo.py`), resolve them relative to the skill directory listed above first, and only consider other paths if needed.
  3) If `SKILL.md` points to extra folders such as `references/`, load only the specific files needed for the request; don't bulk-load everything.
  4) If `scripts/` exist, prefer running or patching them instead of retyping large code blocks.
  5) If `assets/` or templates exist, reuse them instead of recreating from scratch.
- Coordination and sequencing:
  - If multiple skills apply, choose the minimal set that covers the request and state the order you'll use them.
  - Announce which skill(s) you're using and why (one short line). If you skip an obvious skill, say why.
- Context hygiene:
  - Keep context small: summarize long sections instead of pasting them; only load extra files when needed.
  - Avoid deep reference-chasing: prefer opening only files directly linked from `SKILL.md` unless you're blocked.
  - When variants exist (frameworks, providers, domains), pick only the relevant reference file(s) and note that choice.
- Safety and fallback: If a skill can't be applied cleanly (missing files, unclear instructions), state the issue, pick the next-best approach, and continue.
