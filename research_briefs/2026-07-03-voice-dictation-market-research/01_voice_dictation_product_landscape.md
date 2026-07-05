# DeepResearch Task 01: Voice Dictation Product Landscape And LocalVoiceInput Positioning

请基于本任务书中提供的项目背景、约束和已知事实开展研究。不要要求额外项目材料；如背景不足，请在开放问题中标记，而不是自行补全项目事实。

先对齐项目定位：`LocalVoiceInput` 是一个 local-first 的 macOS 跨应用语音输入工具，当前目标是从个人本地高频工具逐步演化为可本地安装、可分发给朋友和同事使用的实用 app。它不是会议录音总结工具，不是云端转写 SaaS，不是系统级输入法，不是自动发送消息的 agent，也不是当前阶段的 App Store 上架项目。本次研究的目标是服务 `LocalVoiceInput` 的具体产品判断，而不是产出脱离项目语境的通用语音识别报告。

研究过程中不要读取或要求任何密钥、账号、密码、`.env`、客户材料、私有凭据、生产数据或未授权材料。外部研究请使用最新公开资料，并给出来源链接。每个重要结论请标注 `confirmed` / `inferred` / `unknown`。如信息可能随时间变化，请注明实际检索日期。

## 研究过程要求

### 项目语境确认

请在报告前部加入项目语境确认，至少包括：

- 你从本任务书中使用了哪些项目背景、约束和已知事实。
- 哪些结论依赖这些已提供事实，哪些来自外部公开资料。
- 本任务边界：本任务是市场、产品、部署形态和体验调研，不是实现方案、融资方案、上架方案或代码审查。
- 你认为仍需项目团队确认的关键假设。

不要声称已经读取本项目的 GitHub、代码仓库或本地文件。本任务书已提供足够的项目事实作为调研锚点。

### 已知项目背景

以下事实由项目团队在 2026-07-03 整理，供外部调研使用。请把这些事实当作本任务的项目锚点。

确认的项目事实：

- `confirmed`: `LocalVoiceInput` 是一个 local-first 的 macOS 语音输入工具，用于跨应用听写输入。
- `confirmed`: 当前产品形态是 macOS 菜单栏 / LSUIElement 常驻小工具，不是 InputMethodKit 输入法，也不是完整前台文档应用。
- `confirmed`: 主要交互是按住 Right Option 说话，松开后输出；`Option + Space` 是长文本模式；`Esc` 取消当前会话。
- `confirmed`: 实时 partial 只显示在非抢焦点浮窗中，不把 partial 直接写入目标输入框。
- `confirmed`: 最终文本会根据焦点安全规则路由到当前光标、剪贴板、fallback copy 或浮窗草稿。
- `confirmed`: 若检测到可编辑、可粘贴、非安全输入框，普通 push-to-talk 模式会尝试自动粘贴；没有输入框、安全输入框、焦点变化、粘贴不确定时会降级到剪贴板。
- `confirmed`: App 依赖 macOS Accessibility、Input Monitoring、Microphone、pasteboard、global event tap，因此必须在真实 Mac 上验证。
- `confirmed`: 当前不默认上传音频或文本到云端，不默认启用云 ASR，不默认启用 LLM correction。
- `confirmed`: 当前实际可用的主要本地 ASR 候选是 Qwen3-ASR MLX 0.6B，通过本机 loopback HTTP service 接入。它不是原生 session streaming API，而是项目自建 segmented-cache wrapper，接收 timed PCM chunks，产生 partial/final 事件。
- `confirmed`: FunASR WebSocket 2-pass 是基线路径；Qwen3-ASR MLX local HTTP 是当前实际使用和继续硬化的候选路径。
- `confirmed`: 当前默认本地端点是 loopback：FunASR `ws://127.0.0.1:10095`，Qwen3 HTTP `http://127.0.0.1:18096`。
- `confirmed`: 当前本地模型缓存约 `10G`；其中 Qwen3 0.6B 约 `964M`，Qwen3 1.7B 约 `2.3G`，MiMo-V2.5-ASR-MLX 约 `4.2G`，MiMo tokenizer 约 `2.4G`，FunASR baseline components 约 `280M` each。
- `confirmed`: 当前 app bundle 约 `1.0M`；模型和 Python/MLX runtime 在 app 外部。
- `confirmed`: Qwen3/MLX 运行时环境约 `583M`。
- `confirmed`: 当前 Qwen3 0.6B segmented baseline 的内部评测摘要：CER `0.0589`，WER `0.0792`，RTF `1.1845`，first partial latency `1077.6 ms`，final latency `184.5 ms`，max peak RSS `1469.0 MB`，numeric pass rate `0.2162`。
- `confirmed`: 当前 Qwen3 1.7B segmented candidate 相比 0.6B 准确率收益有限，延迟和内存成本更高，不建议替代 0.6B 作为默认实时后端。
- `confirmed`: MiMo-V2.5-ASR MLX 当前保留为离线参考，不承担实时主干。
- `confirmed`: 当前分发形态仍偏开发：可以生成本地 `.app`，但尚不是 hardened/notarized 的外部分发 artifact。
- `confirmed`: 下一阶段产品化重点包括服务监督、启动恢复、健康检查、模型/运行时安装、DMG/PKG 分发、权限引导。

项目当前明确不是：

- 不是云端会议转写工具。
- 不是录音整理知识库。
- 不是系统级输入法。
- 不是把所有文本发送给云 LLM 修正的工具。
- 不是自动发送消息或自动操作第三方 app 的 agent。
- 不是当前阶段的 App Store 上架项目。

项目团队当前想确认的问题：

- 市面上是否已有功能形态、部署形态、交互体验、资源成本与 `LocalVoiceInput` 高度类似的产品。
- 如果已有，哪些做得成熟，哪些定位不同，哪些是直接竞品，哪些只是局部参考。
- `LocalVoiceInput` 的本地优先、本机模型、菜单栏常驻、跨应用粘贴、浮窗 partial、安全降级这些特性，在现有商业和开源产品中是否稀缺。
- 在准备做成可本地安装、可分发给朋友同事使用的 macOS app 之前，应参考哪些产品能力、避免哪些定位误判。

### 来源优先级

来源优先级建议：

1. 官方网站、产品文档、价格页、隐私政策、技术文档、帮助中心、release notes。
2. 开源项目主页、README、issues、releases、model/runtime 文档。
3. 学术论文、技术报告、公开 benchmark、可信开源工具或系统文档。
4. 独立评测、用户评论、社区讨论、博客、论坛。使用时请标注偏见或不确定性。

尽量优先检索 2024-2026 年资料。更老的产品可以纳入，但只有在仍活跃维护、仍具代表性或有清晰历史对照价值时才重点讨论。

### 可信度标签

重要结论必须标注可信度：

- `confirmed`: 有明确来源或已提供项目事实支持。
- `inferred`: 基于多个事实合理推断，但没有直接来源。
- `unknown`: 当前资料不足，不能下结论。

不要把 `inferred` 或 `unknown` 包装成确定事实。

### 建议事实卡片格式

建议为关键事实建立事实卡片：

| Fact | Status | Source | Date Checked | Notes |
|---|---|---|---|---|
| ... | confirmed / inferred / unknown | URL or provided project fact | YYYY-MM-DD | ... |

## 本任务目标

请对 2024-2026 年仍活跃或近期出现的语音转文字 / 语音输入 / dictation 产品做广泛调研，并将它们与 `LocalVoiceInput` 的当前产品形态进行对比。重点不是“谁的 ASR 模型最好”这种单点问题，而是完整产品形态：

- 云端 ASR、本地 ASR、混合架构分别怎么做。
- 它们如何融入用户日常输入流。
- 是否支持跨应用输入、自动粘贴、浮窗、快捷键、长文本模式、隐私保护、离线使用。
- 它们在准确率、延迟、资源占用、安装复杂度、价格、隐私、可维护性上各有什么取舍。
- 当前市场上是否已经存在与 `LocalVoiceInput` 高度相似且成熟可用的替代品。

本任务只做资料收集、事实确认、产品类型归纳、风险识别和知识层面的综合。不要给最终技术选型、实施排期或完整工程方案；可以给出对后续产品判断有帮助的启发和开放问题。

## 核心研究问题

- 市面上近两年活跃的语音输入 / dictation / speech-to-text 产品主要有哪些类型？请至少覆盖商业 closed-source、开源工具、半商业开源项目、系统内置功能、模型/runtime 项目。
- 是否存在与 `LocalVoiceInput` 高度类似的产品：macOS 菜单栏或轻量常驻工具、全局快捷键触发、跨应用输入、转写后自动粘贴、本地模型优先、可离线或弱网络依赖？
- Typeless、VoiceInk / Voice Inc、Superwhisper、Wispr Flow、Willow Voice、Aqua Voice、MacWhisper、Whisper.cpp 桌面封装、Buzz、Vibe、OpenAI/Whisper API 客户端、Apple Dictation、Otter、Notta、Descript、Granola 等产品或工具中，哪些与本项目直接相关？哪些只是局部参考？不要局限于这些名称，也请主动发现新的或更准确的产品。
- 云端 ASR 产品与本地 ASR 产品在体验上有哪些可感知差异？例如启动速度、首字延迟、final latency、长文本稳定性、断网可用性、隐私感知、发热/电池、安装门槛、模型更新。
- 这些产品通常如何处理用户交互：push-to-talk、toggle recording、wake word、浮窗、输入法式候选、自动粘贴、剪贴板中转、快捷键配置、历史记录、失败恢复、取消、权限引导？
- 哪些产品已经把“语音输入作为日常跨应用输入工具”做得很好？它们的用户体验细节是什么？
- 哪些产品更偏会议录音/总结、采访转写、字幕生成、文档 dictation、AI 写作助手，而不是跨应用输入工具？请明确区分。
- 哪些产品声称本地处理或离线处理？实际是否完全本地、默认本地、可选本地、还是仅本地缓存/本地 UI + 云端 ASR？
- 对隐私、数据保留、模型下载、价格、账号依赖、企业合规，这些产品如何表达和实现？
- 相比这些产品，`LocalVoiceInput` 当前可能的差异化是什么？差距又在哪里？请从产品体验、技术架构、分发安装、资源成本、质量效果、商业可行性分别讨论。

## 范围内

- 2024-2026 年活跃的 macOS 语音输入 / dictation / speech-to-text 产品。
- 与 macOS 体验强相关的 Windows/iOS/Web 产品，可作为交互或商业模式参考，但不要喧宾夺主。
- 商业产品、开源产品、半商业开源产品、系统自带功能、开发者工具、模型/runtime 项目。
- 云端、本地、混合部署方式的对比。
- 安装方式与分发方式：App Store、DMG、PKG、Setapp、Homebrew、开源 release、pip/npm、model download、账号注册。
- 产品交互体验：快捷键、浮窗、自动粘贴、剪贴板、长文本、错误恢复、权限引导、历史记录。
- 效果和成本：准确率、延迟、长音频稳定性、资源占用、磁盘占用、内存、CPU/GPU/ANE/MLX、耗电、发热。
- 隐私和数据流：音频/文本是否上传、是否可离线、数据保留、隐私政策、企业/团队用法。
- 对 `LocalVoiceInput` 后续分发和产品化阶段有价值的启发。

## 范围外

- 不要设计 `LocalVoiceInput` 的完整实施路线、代码方案或架构改造。
- 不要替项目团队决定是否上架 App Store。
- 不要只做 ASR 模型 benchmark 排名；模型质量只是产品比较的一部分。
- 不要只列产品链接。每个重点产品都要说明形态、部署、体验、价格/许可、证据来源和与本项目的关系。
- 不要研究不相关的会议总结 agent、客服质检系统、呼叫中心 ASR，除非它们有可迁移的交互或部署启发。
- 不要读取或要求任何私有账号、付费后台、用户数据、项目密钥或本机文件。

## 推荐输出结构

不强制完全照此结构输出；如研究内容更适合其他结构，可以调整。但请确保关键事实、来源、开放问题和可复用材料容易被后续综合。

1. Project Context / Scope Confirmation
2. Executive Summary
3. Product Taxonomy
4. Competitive / Reference Product Table
5. Cloud vs Local vs Hybrid Deployment Analysis
6. UX Pattern Analysis
7. Quality / Latency / Resource Cost Evidence
8. Privacy / Data Flow / Pricing / Distribution Comparison
9. Direct Similarity To LocalVoiceInput
10. Gaps, Risks, Unknowns, And Assumptions
11. Implications For LocalVoiceInput
12. Evidence / Fact Cards
13. Cross-Task / Follow-Up Handoff

## 建议对比表字段

请至少做一个产品对比表。字段可按研究发现调整，但建议包括：

| Product | Active? | Platform | Product Type | ASR Deployment | Offline? | Trigger / UX | Cross-App Input | Auto Paste | Partial UI | Long Dictation | Model / Engine | Resource Footprint | Pricing | Privacy Claims | Distribution | Similarity To LocalVoiceInput | Evidence |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|

`Similarity To LocalVoiceInput` 建议用：

- `direct`: 直接竞品或高度类似。
- `adjacent`: 部分形态相似，可参考但不是直接替代。
- `infrastructure`: 更像模型/runtime/SDK，不是用户产品。
- `not comparable`: 主要用途不同。

## 重点比较维度

### 1. 部署与数据流

请明确区分：

- 完全本地：音频和文本默认不出本机。
- 本地模型可选：用户可下载模型离线使用，但默认可能走云。
- 混合：本地 UI + 云端 ASR / LLM。
- 云端：音频或文本上传到服务端处理。
- 不清楚：资料没有说明，标为 `unknown`。

### 2. 用户体验

请重点研究：

- 启动方式：菜单栏、Dock app、输入法、浏览器扩展、后台 helper。
- 触发方式：push-to-talk、toggle、长文本模式、唤醒词、快捷键。
- 输出方式：直接输入、剪贴板、模拟粘贴、系统输入法、文档内插入、API 返回。
- partial 体验：浮窗、目标输入框内实时显示、录完后才输出。
- 失败恢复：取消、撤回、保留剪贴板、历史记录、重新识别。
- 权限引导：麦克风、辅助功能、输入监控、屏幕录制或自动化权限。

### 3. 效果与成本

请尽量找到可核实证据，不能只依赖营销描述：

- 准确率或用户可感知质量，尤其是中文、英文、中英混合、技术词、数字格式。
- 首个 partial latency、录完到 final 的等待时间、长文本稳定性。
- 本地资源占用：模型大小、内存、CPU/GPU、发热、电池、启动时间。
- 安装成本：是否需要手动安装模型/runtime，是否需要 Python、Homebrew、Xcode、命令行。
- 维护成本：模型更新、macOS 权限、notarization、自动启动、错误恢复。

### 4. 商业与分发

请比较：

- 免费、一次性购买、订阅、用量计费、企业版。
- App Store、官网 DMG、PKG、Setapp、Homebrew、开源 release、命令行。
- 对中国大陆用户的可获得性和支付/网络依赖，如资料可查则说明；查不到标 `unknown`。

## 输出要求

- 用中文输出。
- 给出来源链接和检索日期。
- 对重要结论标注 `confirmed` / `inferred` / `unknown`。
- 明确区分事实、推断、建议和开放问题。
- 避免把产品营销用语直接当成事实；隐私、离线、本地模型、准确率、资源占用必须尽量找实证或官方文档。
- 对每个重点产品至少给出 1-3 个来源；对时间敏感事实给出检索日期。
- 如果信息互相冲突，请保留冲突而不是强行调和。
- 不要读取或要求任何敏感材料。

## Cross-Task / Follow-Up Handoff

本次只有一个综合调研任务，无跨任务依赖。请在末尾加入后续交接清单，至少包括：

- 可直接交给后续综合任务使用的产品分类表和竞品对比表。
- 与 `LocalVoiceInput` 后续产品化有关的机会点、风险点和未知点。
- 需要本地验证、工程验证或人工试用的问题，例如资源占用、中文质量、权限体验、长文本模式、离线能力。
- 值得沉淀进长期知识库的产品、文档、benchmark、用户评价或设计模式。

## 落地交付说明

不强制使用某一种报告格式；请根据研究内容选择最清晰的组织方式。

如果目标工具支持文件产物，请把研究产物按类别分文件夹放置，例如：

- 主报告
- 产品对比表
- 事实卡片
- 来源材料清单
- 交互模式截图或说明
- 云端/本地/混合部署分类
- 风险和开放问题
- 可交给后续任务的交接清单

并将整个任务成果目录打包成一个 `.zip` 文件，供下载和归档。

如果目标工具不支持文件夹或 zip，请用清晰标题分隔这些内容，保证后续可以手动归档。
