<h1 align="center">claude-checkpoint</h1>

<p align="center">
  <strong>Claude Codeのためのセッションコンテキスト永続化ツール</strong>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License: MIT"></a>
  <img src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey.svg" alt="Platform">
  <img src="https://img.shields.io/badge/requires-Claude%20Code%20CLI-blueviolet.svg" alt="Requires Claude Code">
  <img src="https://img.shields.io/badge/shell-bash-green.svg" alt="Shell: Bash">
  <br>
  <a href="README.md"><img src="https://img.shields.io/badge/🇺🇸_English-white.svg" alt="English"></a>
  <a href="README.ko.md"><img src="https://img.shields.io/badge/🇰🇷_한국어-white.svg" alt="한국어"></a>
  <a href="README.ja.md"><img src="https://img.shields.io/badge/🇯🇵_日本語-white.svg" alt="日本語"></a>
</p>

<p align="center">
  Claude CodeのHookシステムを活用し、作業状態を自動的に保存・復元します。<br>
  新しいセッションのたびに<em>「どこまでやったっけ？」</em>と悩む必要はもうありません。
</p>

---

## 課題

Claude Codeのセッションは、さまざまな形でコンテキストを失います：

- **新しいセッション**の開始や**ターミナルの終了** — すべてのコンテキストが失われる
- **`/clear`** の実行 — すべてのコンテキストが失われる
- **Compact** — コンテキストは圧縮されるが、ファイルパスや正確な進捗状況、タスクチェックリストなどの詳細が要約の過程で失われる可能性がある

毎回進捗を説明し直したり、圧縮後に重要な詳細を失うことになります。

## 解決策

`claude-checkpoint`はClaude Codeのライフサイクルにフックし、**自動セーブポイント**を作成します：

```
  通常通り作業
       │
       ▼
  git commit ──────► チェックポイント自動保存
       │
       ▼
  セッション終了（クラッシュ、終了、compact、/clear）
       │
       ▼
  新しいセッション開始
       │
       ▼
  チェックポイントをコンテキストに復元 ──► Claudeが作業を引き継ぎ
```

インストール後の設定不要。覚えるコマンドなし。

## クイックスタート

```bash
# 1. クローン
git clone https://github.com/Canto87/claude-checkpoint.git

# 2. プロジェクトにインストール
./claude-checkpoint/install.sh /path/to/your/project

# 3. 完了。通常通り作業を始めましょう。
```

> **必要条件:** [Claude Code CLI](https://docs.anthropic.com/en/docs/claude-code)、`jq`、Git

## 仕組み

### イベントとアクション

| イベント | アクション |
|:---------|:-----------|
| `git commit` | チェックポイント保存（完了した作業、次のタスク、参照ドキュメント） |
| セッション開始 | 現在のブランチのすべてのチェックポイントをコンテキストに復元 |
| `/clear` | 現在のブランチのすべてのチェックポイントをコンテキストに復元 |
| Compact | チェックポイント復元 + 未保存の状態の保存を促進 |

### ファイル構造

チェックポイントはClaude Codeのauto-memoryディレクトリに保存されます：

```
~/.claude/projects/{encoded-project-path}/memory/
├── MEMORY.md                        # 長期知識（ユーザーが管理）
├── checkpoint-main-12345.md         # mainブランチ セッションA
├── checkpoint-main-67890.md         # mainブランチ セッションB
└── checkpoint-feat-auth-11111.md    # featureブランチ セッション
```

- **MEMORY.md** — プロジェクトのパターン、重要な決定事項、長期メモ
- **checkpoint-\*.md** — 現在のタスク状態、次のステップ、参照ドキュメント（自動管理）

### マルチセッション安全性

各セッションは固有のチェックポイントファイルに書き込みます：

```
checkpoint-{ブランチ}-{セッションPID}.md
```

同じプロジェクトでの並列セッションが競合することはありません。復元時には現在のブランチのすべてのチェックポイントが読み込まれ、並行作業の全体像を把握できます。

**24時間**を超えた古いチェックポイントは自動的にクリーンアップされます。

### チェックポイント形式

```markdown
# Checkpoint

## Last Updated
- Date: 2025-01-15
- Commit: abc1234

## Completed Work
- ユーザー認証モジュールを実装

## Current Roadmap Position
- Roadmap: docs/plans/ROADMAP.md
- Current step: Phase 2 - API連携
- Status: in progress

## Next Task Checklist
- [ ] トークンリフレッシュロジックの追加
- [ ] 統合テストの作成

## Reference Docs
- docs/plans/auth-design.md
- docs/API.md
```

## アーキテクチャ

```
┌──────────────────────────────────────────────────────────┐
│                     Claude Code CLI                      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│  PostToolUse Hook（Bash対象）                              │
│  ┌────────────────────────────────────────────────────┐  │
│  │  `git commit`を検出 → チェックポイント保存トリガー    │  │
│  │  post-commit-checkpoint.sh                         │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  SessionStart Hook（startup / clear / compact）           │
│  ┌────────────────────────────────────────────────────┐  │
│  │  チェックポイントファイル読み込み → コンテキストに注入 │  │
│  │  session-restore.sh                                │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
├──────────────────────────────────────────────────────────┤
│  ~/.claude/projects/*/memory/                            │
│  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │  MEMORY.md   │  │  checkpoint-{branch}-{pid}.md    │  │
│  │  (長期記憶)   │  │  (短期記憶、セッション別)         │  │
│  └──────────────┘  └──────────────────────────────────┘  │
└──────────────────────────────────────────────────────────┘
```

## インストール / アンインストール

### インストール

```bash
./install.sh /path/to/your/project
```

実行内容：
1. Hookスクリプトを`.claude/hooks/`にコピー
2. Hook設定を`.claude/settings.json`にマージ（既存のhooksは保持）
3. プロジェクトの`MEMORY.md`にセッションプロトコルセクションを追加

### アンインストール

```bash
./uninstall.sh /path/to/your/project
```

`claude-checkpoint`のhookエントリのみを削除します。他のhooksや設定には影響しません。

> `~/.claude/projects/*/memory/`内のチェックポイントファイルは**自動削除されません。**
> 不要な場合は手動で削除してください。

## トークンコスト

Hookスクリプト自体は**純粋なシェルスクリプト**であり、**APIトークンを消費しません。**

トークンが消費されるのは：
- **セッション開始時のチェックポイント内容の注入**（チェックポイントあたり約200-500トークン）
- **コミット時のClaude によるチェックポイント作成**（約300-600トークン）

通常の会話使用量と比較して無視できるレベルです。

## FAQ

**Q: コミットし忘れた場合は？**
チェックポイントは`git commit`時にのみ保存されます。コミット前にセッションが終了した場合、最後のコミット時のチェックポイントが使用されます。こまめなコミットをお勧めします。

**Q: チェックポイントファイルを手動で編集できますか？**
はい、通常のMarkdownファイルです。ただし、そのセッションでの次のコミット時に上書きされます。

**Q: Worktreeでも動作しますか？**
はい。各worktreeは固有のブランチを持つため、チェックポイントは自然に分離されます。

**Q: `jq`がインストールされていない場合は？**
インストールスクリプトがエラーで終了します。`brew install jq`（macOS）または`apt install jq`（Linux）でインストールしてください。

## コントリビュート

コントリビューションを歓迎します！Issueを作成するか、Pull Requestを送ってください。

## ライセンス

[MIT](LICENSE)
