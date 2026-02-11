---
name: skill-fetcher
description: Agent Registryからスキル・サブエージェント・ワークフロー・チェックリストを取得するブートストラップスキル。
---

# Skill Fetcher

Agent Registryから必要なリソースを取得する。

---

## 取得対象

| 種類 | 配置先 | 用途 |
|------|-------|------|
| skills | `.agent/skills/` | 開発ガイドライン、実装方法 |
| subagents | `.agent/subagents/` | AIエージェントのロール定義 |
| workflows | `.agent/workflows/` | 開発フロー |
| checklists | `.agent/checklists/` | 確認リスト |

---

## カタログ参照

https://raw.githubusercontent.com/t2k2pp/agent-registry/main/catalog.yaml

---

## 取得コマンド

### スキル取得

```powershell
# PowerShell
$path = "core/skills/ai-development-guidelines"
$url = "https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path/SKILL.md"
$dest = ".agent/skills/$(Split-Path $path -Leaf)"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Invoke-WebRequest -Uri $url -OutFile "$dest/SKILL.md"
```

```bash
# Bash
path="core/skills/ai-development-guidelines"
url="https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path/SKILL.md"
dest=".agent/skills/$(basename $path)"
mkdir -p "$dest" && curl -sL "$url" -o "$dest/SKILL.md"
```

### サブエージェント取得

```powershell
# PowerShell
$path = "domains/mobile/flutter/subagents/flutter-developer.md"
$url = "https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path"
$dest = ".agent/subagents"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Invoke-WebRequest -Uri $url -OutFile "$dest/$(Split-Path $path -Leaf)"
```

```bash
# Bash
path="domains/mobile/flutter/subagents/flutter-developer.md"
url="https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path"
dest=".agent/subagents"
mkdir -p "$dest" && curl -sL "$url" -o "$dest/$(basename $path)"
```

### ワークフロー取得

```powershell
# PowerShell
$path = "domains/mobile/flutter/workflows/development-flow.md"
$url = "https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path"
$dest = ".agent/workflows"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Invoke-WebRequest -Uri $url -OutFile "$dest/$(Split-Path $path -Leaf)"
```

```bash
# Bash
path="domains/mobile/flutter/workflows/development-flow.md"
url="https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path"
dest=".agent/workflows"
mkdir -p "$dest" && curl -sL "$url" -o "$dest/$(basename $path)"
```

### チェックリスト取得

```powershell
# PowerShell
$path = "domains/mobile/flutter/checklists/build-troubleshooting.md"
$url = "https://raw.githubusercontent.com/t2k2pp/agent-registry/main/$path"
$dest = ".agent/checklists"
New-Item -ItemType Directory -Force -Path $dest | Out-Null
Invoke-WebRequest -Uri $url -OutFile "$dest/$(Split-Path $path -Leaf)"
```

---

## Flutter開発セット一括取得

```powershell
# PowerShell - Flutter開発に必要な基本セット
$base = "https://raw.githubusercontent.com/t2k2pp/agent-registry/main"

# スキル
@(
  "core/skills/ai-development-guidelines",
  "domains/mobile/common/skills/mobile-ux",
  "domains/mobile/flutter/skills/flutter-development",
  "domains/mobile/flutter/skills/flutter-environment-check"
) | ForEach-Object {
  $dest = ".agent/skills/$(Split-Path $_ -Leaf)"
  New-Item -ItemType Directory -Force -Path $dest | Out-Null
  Invoke-WebRequest -Uri "$base/$_/SKILL.md" -OutFile "$dest/SKILL.md"
}

# サブエージェント
@(
  "domains/mobile/flutter/subagents/flutter-developer.md",
  "domains/mobile/common/subagents/mobile-architect.md"
) | ForEach-Object {
  New-Item -ItemType Directory -Force -Path ".agent/subagents" | Out-Null
  Invoke-WebRequest -Uri "$base/$_" -OutFile ".agent/subagents/$(Split-Path $_ -Leaf)"
}

# ワークフロー
@(
  "domains/mobile/flutter/workflows/development-flow.md"
) | ForEach-Object {
  New-Item -ItemType Directory -Force -Path ".agent/workflows" | Out-Null
  Invoke-WebRequest -Uri "$base/$_" -OutFile ".agent/workflows/$(Split-Path $_ -Leaf)"
}

Write-Output "Flutter development set downloaded!"
```

---

## 推奨取得順序

| 優先度 | 種類 | 内容 |
|-------|------|------|
| 1 | skill | ai-development-guidelines（必須） |
| 2 | skill | FW固有（flutter-development等） |
| 3 | subagent | 開発者ロール（flutter-developer等） |
| 4 | workflow | 開発フロー |
| 5 | checklist | 必要に応じて |
