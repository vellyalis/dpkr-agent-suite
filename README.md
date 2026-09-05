# DPKR Agent Suite

> **強いAIに、ただコードを書かせるな。**
> **設計・責任分離・検証・UI品質まで、ちゃんと仕事をさせろ。**

Current bundle: **1.0.6**
`FrontierLoop 0.8.5` + `Native UI Governance 1.0.6` + bundled global `AGENTS.md`

DPKR Agent Suite は、Codex / Taddkorro で使うための **AI開発ガバナンス + Engineering Skill + Native UI Skill の統合セット**です。

単に「便利そうなSkillを27個ぶち込んだ全部盛り」ではありません。そんな闇鍋は、まぁ多少はね？では済まないのでやめています。

このSuiteの目的は、AIに次のような期待動作をさせることです。

- 明白な変更は、余計な会議を始めずサッと実装する。
- 難しい変更では、まず正本・責任・寿命・境界を見極める。
- 原因不明バグを、思いつき修正ではなく因果証拠から潰す。
- Cache / Scan / Polling / Worker / Queue を「なんとなく」で増やさない。
- Coreや共通層へ、将来使いそうというだけで機能を押し込まない。
- 既存手段では要求を満たせないなら、独自Engine / Framework / Renderer / Runtimeも第一原理から作る。
- UIは「コンパイル通ったから完成！」で終わらせず、実際のNative画面で検証する。
- AI生成物にありがちな、カード・Pill・Glass・Gradient盛り盛りの謎ダッシュボード化を抑える。
- 必要なSkillだけを読み、毎回フルコースを召喚しない。
- Skill名がCatalogに見えるだけで「使ったこと」にせず、必要な`SKILL.md`本文まで実際にロードする。

要するに、**AIを「コード自動生成機」ではなく、シニアエンジニア + UIチームとして安定運用しやすくするためのセット**です。やりますねぇ！

---

## 何が入っている？

| 構成 | 役割 |
| --- | --- |
| **FrontierLoop** | Engineering判断、Architecture、Debug、Performance、Migration、Verification、R&D |
| **Native UI Governance** | UI方向性、Native UI実装、Visual QA、Motion |
| **global `AGENTS.md`** | どのSkillを、いつ、どこまで使うかを決める共通Router / Constitution |
| **DPKR Agent Suite** | Git取得、Version pin、Codex登録、Taddkorro登録、Install、Update、Verify |

この3層をセットで使うのが前提です。

```text
global AGENTS.md
       |
       |  task routing
       v
+-----------------------+
|     FrontierLoop      |
| Engineering / R&D     |
+-----------------------+
       |
       | visible native UI work
       v
+-----------------------+
| Native UI Governance  |
| Design / UI / QA      |
+-----------------------+
       |
       v
 Verified Deliverable
```

**FrontierLoopだけでも強い。Native UI Governanceだけでも役に立つ。だがセットで使うと責任分担が完成する。** ここ大事だから、よーく見とけよ見とけよ～。

---

# FrontierLoop — 「どう作るべきか」を判断するEngineering層

FrontierLoopは、一般的な「SOLIDを守ろう」「テストを書こう」みたいなBest Practice集ではありません。

主眼は、**変更の因果面・正本・責任・寿命・境界を見極め、最小の責任正しい実装を選ぶこと**です。

## FrontierLoopが特に強いこと

### 1. Source of Truth / Owner / Lifetime

状態を増やす前に、まず聞きます。

```text
このデータの正本はどこ？
誰が書く権限を持つ？
いつ生成される？
いつ無効になる？
いつ破棄される？
本当にコピーを持つ必要がある？
```

たとえば「現在選択中の対象を保存したい」だけなのに、常時60Hzで全体ScanしてCacheしてBackground Workerで同期する――みたいな、迫真の過剰設計部を作る前に、**保存時にauthoritative stateを直接読めないか**を先に考えます。

### 2. FOUNDATION → REDUCTION → REALITY

Structuralな変更では、共有Engineering Judgmentを使います。

**FOUNDATION**
正本、Owner、Lifetime、Data Flow、Boundaryを確定する。

**REDUCTION**
不要なCache、Scan、Polling、Queue、Worker、Fallback、互換層、抽象化を削れるか考える。

**REALITY**
実際のLatency、CPU、GPU、Memory、Concurrency、Failure、Maintenance costで成立するか確認する。

「理論上きれい」ではなく、**現物で成立するか**まで見るのがポイントです。

### 3. Architecture / 責任分離

ファイルが長いから分割、似ているから共通化、という雑な判断はしません。

次のどれかが独立して変化するときに、Moduleや責任を分けます。

- Change reason
- State / invariant owner
- Lifetime / cancellation
- Failure / recovery
- I/O / side effect
- Dependency direction
- Public contract
- Security boundary
- Verification seam

逆に、同じState・Invariant・Lifetimeを共有するものは、無理にバラバラにしません。

**巨大Monolithも、1関数1ファイル教も、どっちもダメです。** 当たり前だよなぁ？

### 4. 原因不明Bugの因果解析

`frontier-debug-investigation`は、特に次に向いています。

- Race condition
- Shutdown / cancellation
- intermittent bug
- 環境依存
- 複数層に跨る障害
- 何度直しても再発する不具合

「怪しいところ全部修正しました！」ではなく、再現境界・競合仮説・識別実験・因果証拠を作り、**Mechanism-level fix**へ持っていきます。

### 5. Performance Engineering

次のような問題もFrontierLoopの守備範囲です。

- 入力遅延
- Frame time / jitter
- CPU / GPU負荷
- Memory / allocation
- Startup
- I/O
- Lock contention
- Backpressure
- 大量Scan / Polling

特に「動いているからいいだろ」で常時処理を積み上げるのを嫌います。

測定された問題に対して、**どの因果経路がコストを作っているか**を見て改善します。

### 6. Migration / Clean Break / Fail-Closed

古い経路を永遠に残すのも、いきなり全部消すのも避けます。

```text
real consumer確認
    ↓
移行
    ↓
新ownerへ責任移譲を検証
    ↓
cutover
    ↓
旧path / flag / alias / test / docを削除
```

また、正しさ・永続化・権限・外部契約などで保証できない状態を、適当なFallbackで成功扱いしません。

**分からないなら分からないまま止める。壊れてるのにSuccessを返すな。** これがFail-Closedです。

---

## まだ世の中にないものを作るのにも向いている

ここ重要。

FrontierLoopは「既存Libraryを使え」「新しいFrameworkを作るな」という保守的なSkillではありません。

`frontier-deep-engineering`は、明示的に次を対象にしています。

- 独自UI Framework
- Renderer
- Runtime
- Engine
- Compiler
- Scheduler
- Storage Engine
- Protocol
- Interoperability Layer
- Audio / Graphics path
- Real-time system
- Low-level concurrency
- ABI / binary format
- Hardware-specific mechanism

既存技術でRequirementを満たせるなら再利用する。
満たせないEvidenceがあるなら、**第一原理から新しいMechanismを作る。**

このときも、いきなり巨大Frameworkを全部作りません。

```text
Problem model
   ↓
Current Best / prior art
   ↓
Reuse / Adapt / Build 判断
   ↓
独立Oracle
   ↓
最小の本物のVertical Slice
   ↓
実測・反証
   ↓
成立したInvariantだけGeneralize
```

たとえば新しいNative UI Frameworkなら、

```text
Declarative description
      ↓
State / reconciliation
      ↓
Layout
      ↓
Text / IME / Focus
      ↓
GPU renderer
      ↓
Native window / input
```

という本物のend-to-end sliceを先に成立させ、そこからAPIやComponent Systemを育てます。

**新規Framework / Renderer / RuntimeのR&Dは、FrontierLoopがかなり得意な領域です。**

---

# Native UI Governance — 「どう見せ、どうNative実装するか」を担当

FrontierLoopがEngineering責任を持つ一方、Native UI Governanceは**UIの品質そのもの**を扱います。

特に、HTML/CSSのテンプレ感をNative UIへ雑に持ち込んだり、AIが好きそうなカードとPillを大量発生させたりするのを抑えます。

4つのSkillを役割ごとに分離しています。

## `native-design-director`

**「何を、どう見せるべきか」**を決めるSkill。

向いているもの:

- 新しい画面
- UI redesign
- 情報階層が弱い画面
- 視線誘導が崩れている画面
- DenseなProfessional Tool
- 製品固有のVisual Identityを作りたいとき

見るもの:

- Primary task
- First read / Second read
- Spatial composition
- Density
- Contrast budget
- Depth hierarchy
- Material physics
- Typography
- Icon / control coherence
- Product signature

また、次のような**AI臭いDefault Styling**を明示的に警戒します。

- Floating rounded cardsだらけ
- Pill / Badgeだらけ
- 意味のないGradient
- 意味のないGlass / Glow
- Expert ToolなのにMarketing Siteみたいな巨大余白
- Fake analytics / fake metrics
- 左Rail + Card Grid + Chat Columnの量産構成
- 全部同じRadius / Border / Shadow

「なんか高級そう」ではなく、**その製品に必要なVisual Languageか**で判断します。

## `native-ui-system`

方向性が決まった後、Native UIとして正しく実装するSkillです。

```text
Semantic system tokens
        ↓
Component metrics / anatomy
        ↓
Surface-specific layout
```

を分離しながら、次まで扱います。

- Layout
- Component state matrix
- Hover / Pressed / Selected / Disabled
- Focus-visible
- Keyboard
- IME
- Localization
- DPI
- Resize
- Accessibility
- Theme / renderer consistency
- Performance-sensitive effects

つまり「スクショに似せる」だけではなく、**実際に使えるNative UI component system**へ落とします。

## `native-visual-qa`

**コンパイル成功 ≠ UI完成。**

ここを容赦なく分離します。

```text
Screenshot          → composition / appearance
UI tree / geometry  → bounds / clipping / alignment
Runtime measurement → performance
Human               → unresolved taste
```

本物のshipped rendering pathを観測できるなら、SourceやMockだけでVisual PASSにしません。

「できました！」→ 実画面見たらズレてるじゃねえかオォン！？を減らすためのSkillです。

## `native-motion-craft`

Motionは**static UIが成立した後だけ**。

「もっと生き生きさせて」と言われて、全部に謎Animationを付ける迫真モーション部を防ぎます。

各Motionについて、

- 本当に動かす必要があるか
- Feedback / spatial continuity / state legibilityのどれに必要か
- 頻度
- Interrupt / retarget
- Reduced Motion
- Renderer cost
- Input latencyへの影響

を確認します。

高頻度・Keyboard-drivenな操作は、基本的にinstantまたは極小Motionを優先します。

---

# 2つを組み合わせるとどう動く？

たとえば新しいNative UI機能を作る場合:

```text
User Goal
   ↓
frontier-core
   ↓
必要なら architecture / deep-engineering / performance
   ↓
正本・Owner・Lifetime・API・Mechanismを決定
   ↓
native-design-director   ← visual directionが未確定なら
   ↓
native-ui-system         ← 実装
   ↓
実アプリ起動
   ↓
native-visual-qa         ← 本物のrenderで合否
   ↓
native-motion-craft      ← 本当に必要なら
   ↓
Verified Deliverable
```

毎回全部を読むわけではありません。

**必要なSkillだけ起動する。** これがこのSuiteの重要な設計です。

---

# 期待するAIの挙動

このSuiteを導入すると、AIに次のような挙動を期待できます。

| 状況 | 期待動作 |
| --- | --- |
| typo / private rename | 余計なSkillをロードせず即修正 |
| 普通の非自明な変更 | `frontier-core`でWork Unitを所有 |
| Ownership / Lifetime変更 | Engineering Judgment + Architecture |
| 原因不明Bug | Debug Investigationで因果証拠を取る |
| Performance問題 | 実測してPerformance Engineering |
| 新規Framework / Renderer | 必要ならDeep EngineeringでR&D |
| UI方向性が未確定 | Design Director |
| UI実装 | Native UI System |
| UI完成判定 | Real render + Visual QA |
| Motion | static UI合格後だけMotion Craft |
| Skill本文が読めない | 使用済みと偽装せずFail-Closed |

特に狙っているのは、**「強いモデルなのに、余計な仕組みを勝手に足してプロジェクトを複雑にする」事故の削減**です。

モデルのIQそのものを増やす魔法ではありません。
持っている能力を、より一貫した設計・実装・検証へ変換しやすくするHarnessです。

---

# どういう開発に向いている？

かなり広く使えますが、特に相性がいいのは次です。

### Native / Systems

- Rust / C++ Native Desktop App
- UI Framework / Widget Toolkit
- Renderer / GPU pipeline
- DAW / Audio Engine
- Desktop Shell
- Game Tooling
- Real-time system
- Runtime / Compiler / Protocol

### 大規模Application

- Stateが複雑
- Plugin / Moduleが多い
- Background taskが多い
- 長期開発でArchitectureが崩れやすい
- AI実装で重複StateやFallbackが増えやすい

### 改善・修復

- 入力遅延
- 大量Scan
- 起動が重い
- Memory増大
- Race / shutdown bug
- 過剰抽象化
- 巨大ファイル
- 二重Source of Truth
- Legacy path整理
- Migration

### UI品質

- Native desktop UI
- Dense professional tool
- 高品質Design System
- Apple / DAW / IDE系の高密度UI
- 「AI臭いUI」を避けたい製品

---

# このSuiteがやらないこと

なんでも自動で正解にする装置ではありません。

- モデルそのものの知識やVisual perceptionを魔法のように増やすわけではない。
- Product valueや最終Tasteを人間から奪わない。
- 不要なDaemon / Watcher / SQLite / Background updaterを増やさない。
- 全Skillを毎回ロードしない。
- 既存のdirty workを勝手にreset / clean / stashしない。
- 「将来使えそう」だけを理由にFrameworkやCore abstractionを増やさない。
- MockやSource inspectionだけで、実UIを見たことにしない。

つまり、AIに好き放題させるためではなく、**自由に作らせつつ、責任と証拠を持たせるためのSuite**です。

いいゾ～これ。

---

# 導入

## Windows Quick Install

Requirements:

- Git
- PowerShell 7+
- Codex CLI（Codexでも使う場合）
- Taddkorro（Taddkorroでも使う場合）

```powershell
git clone https://github.com/vellyalis/dpkr-agent-suite.git "$env:USERPROFILE\plugins\dpkr-agent-suite"
cd "$env:USERPROFILE\plugins\dpkr-agent-suite"
.\install.ps1
```

Clean profileなら、これでセット全体を導入します。

`%USERPROFILE%\.codex\AGENTS.md` がすでに存在し、Suite同梱版と内容が異なる場合は**勝手に上書きしません**。

同梱版を明示的に採用する場合:

```powershell
.\install.ps1 -ReplaceGlobalAgents
```

既存の`AGENTS.md`はtimestamp付きBackupを作ってから置換します。

---

# 何が登録される？

## Codex

- `personal` marketplaceへ2 pluginを登録
- `.codex-plugin/plugin.json`を検証
- Codex CLI自身の`plugin marketplace/list`で実認識を確認
- 27 Skillを`%USERPROFILE%\.agents\skills`へmaterialize
- global routerを`%USERPROFILE%\.codex\AGENTS.md`へ導入

**marketplace.jsonに文字が書いてあるだけではPASSにしません。**
Codex自身が`installed=true / enabled=true`として認識するところまで検証します。

## Taddkorro

- 各pluginの`taddkorro.plugin.json`を検証
- 同じ27 Skillを`.agents\skills`からdiscover
- SkillはJunctionではなく実ディレクトリとしてmaterialize
- Taddkorroのinstruction-resolution boundary内から`SKILL.md`本文を読める状態にする
- CatalogにIDが見えることと、本文が実ロードされたことを別物として扱う

---

# Verify

```powershell
.\verify.ps1
```

Verifierは次を確認します。

- FrontierLoop source / cache
- Native UI Governance source / cache
- Codex manifest
- Taddkorro manifest
- Personal marketplace ownership
- Codex CLIの実runtime登録状態
- global `AGENTS.md`
- 27 materialized Skills
- Versioned cache
- Source / installed drift

---

# Update

```powershell
.\update.ps1
```

Suite checkoutを可能な場合だけfast-forwardし、新しい`suite.json`でpinされたcomponent versionを導入します。

Dirty / diverged Git treeはFail-Closedします。

```text
reset   しない
clean   しない
stash   しない
force   しない
```

迫真Git保全部。

---

# Source Ownership

```text
GitHub FrontierLoop                  GitHub native-ui-governance
        |                                      |
        v                                      v
~/plugins/frontier-loop             ~/plugins/native-ui-governance
        |                                      |
        +---------- verified installers -------+
                           |
              ~/.codex/plugins/cache/personal/...
                           |
                  ~/.agents/skills/*

dpkr-agent-suite owns only:
  - version pins
  - marketplace registration
  - bundled global AGENTS.md
  - orchestration / verification
```

Skill本文のCanonical OwnerをSuite側へ複製しません。

**一つの意味には一つの正本。二重Ownerは、まずいですよ！**

---

## Repositories

- FrontierLoop: <https://github.com/vellyalis/FrontierLoop>
- Native UI Governance: <https://github.com/vellyalis/native-ui-governance>
- DPKR Agent Suite: <https://github.com/vellyalis/dpkr-agent-suite>
