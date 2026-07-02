# LocalVoiceInput 全量本地 ASR 模型测评报告

## 范围

- Manifest case row：1
- 唯一音频文件：1
- 缺失音频：0

正式验收以 manifest case row 为准；去重音频统计只作为解释辅助。

## 指标说明

- CER: 字符错误率，越低越好。按标准答案和识别结果的字符级编辑距离除以标准答案字符数计算，主要用于中文识别准确率。
- WER: 词或 token 错误率，越低越好。中文近似按单字 token，连续英文、数字和符号按一个 token，用来观察中英混合和技术词错误。
- RTF: 实时因子，越低越快。RTF=0.5 表示处理耗时约为音频时长的一半；RTF>1 表示慢于实时。
- RSS: 进程常驻内存，单位 MB。peak RSS 是峰值内存，mean RSS 是采样平均内存。
- CPU: 进程 CPU 使用率。peak CPU 是采样峰值，mean CPU 是采样平均值。
- first_partial_latency_ms: 从开始输入音频到第一段实时文字出现的延迟，越低越好。
- partial_cadence_ms: 实时 partial 文本的平均刷新间隔，越低表示浮窗更新越频繁。
- final_latency_ms: 停止输入后最终结果返回延迟，越低越好。
- final_coverage_ratio: 最终文本长度相对于标准答案长度的比例，用于发现漏识别、截断或异常过长输出。
- numeric_format_pass_rate: 数字格式约束通过率，用于观察阿拉伯数字、日期、小数、百分比、金额、版本号等格式偏好。

## 模型

| 模型 | 厂商 | 参数量级 | 发布时间 | 路径 | 角色 |
|---|---|---|---|---|---|
| qwen3-asr-0.6b-mlx-8bit | 上游为阿里 / 通义千问 Qwen；MLX Community 转换 | 0.6B parameters, 8-bit quantized MLX weights | 2026-01-29 | `.external/models/mlx-community__Qwen3-ASR-0.6B-8bit` | current_baseline |
| qwen3-asr-1.7b-mlx-8bit | 上游为阿里 / 通义千问 Qwen；MLX Community 转换 | 1.7B parameters, 8-bit quantized MLX weights | 2026-01-29 | `.external/models/mlx-community__Qwen3-ASR-1.7B-8bit` | larger_qwen_candidate |
| mimo-v2.5-asr-mlx | 小米 MiMo 团队 | 8B parameters | 2026-06-02 | `.external/models/MiMo-V2.5-ASR-MLX` | high_quality_offline_candidate |

## 总览：Raw Manifest Rollup

| 模型 | 模式 | cases | CER | WER | RTF | first partial ms | final latency ms | final coverage |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| mimo-v2.5-asr-mlx | file_level | 1 | 0.0000 | 0.0000 | 0.2102 | n/a | 1323.1 | 1.0000 |
| mimo-v2.5-asr-mlx | segmented | 1 | n/a | n/a | n/a | n/a | n/a | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | 1 | 0.1053 | 0.1053 | 0.0253 | n/a | 159.3 | 0.9474 |
| qwen3-asr-0.6b-mlx-8bit | segmented | 1 | 0.1053 | 0.1053 | 1.2693 | 1086.8 | 147.2 | 0.9474 |
| qwen3-asr-1.7b-mlx-8bit | file_level | 1 | 0.1053 | 0.1053 | 0.0440 | n/a | 276.7 | 0.9474 |
| qwen3-asr-1.7b-mlx-8bit | segmented | 1 | 0.1053 | 0.1053 | 1.3558 | 1124.3 | 256.5 | 0.9474 |

## 总览：Deduplicated Audio Rollup

| 模型 | 模式 | unique-like cases | CER | WER | RTF | final latency ms | final coverage |
|---|---|---:|---:|---:|---:|---:|---:|
| mimo-v2.5-asr-mlx | file_level | 1 | 0.0000 | 0.0000 | 0.2102 | 1323.1 | 1.0000 |
| mimo-v2.5-asr-mlx | segmented | 1 | n/a | n/a | n/a | n/a | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | 1 | 0.1053 | 0.1053 | 0.0253 | 159.3 | 0.9474 |
| qwen3-asr-0.6b-mlx-8bit | segmented | 1 | 0.1053 | 0.1053 | 1.2693 | 147.2 | 0.9474 |
| qwen3-asr-1.7b-mlx-8bit | file_level | 1 | 0.1053 | 0.1053 | 0.0440 | 276.7 | 0.9474 |
| qwen3-asr-1.7b-mlx-8bit | segmented | 1 | 0.1053 | 0.1053 | 1.3558 | 256.5 | 0.9474 |

## 分 Suite 结果

| 模型 | 模式 | suite | cases | CER | WER | RTF | peak RSS MB | peak CPU % | numeric pass |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| qwen3-asr-0.6b-mlx-8bit | file_level | smoke | 1 | 0.1053 | 0.1053 | 0.0253 | 668.9 | 73.1 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | smoke | 1 | 0.1053 | 0.1053 | 0.0440 | 2348.0 | 83.0 | n/a |
| mimo-v2.5-asr-mlx | file_level | smoke | 1 | 0.0000 | 0.0000 | 0.2102 | 7082.6 | 159.5 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | smoke | 1 | 0.1053 | 0.1053 | 1.2693 | 1185.2 | 74.1 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | smoke | 1 | 0.1053 | 0.1053 | 1.3558 | 2573.2 | 87.6 | n/a |
| mimo-v2.5-asr-mlx | segmented | smoke | 1 | n/a | n/a | n/a | n/a | n/a | n/a |

## 初步解释

- `file_level` 只代表整段音频最终识别质量，不能单独证明适合作为实时语音输入后端。
- `segmented` 更接近 LocalVoiceInput 当前浮窗和长语音输入路线。
- MiMo 如果只有 `unsupported_segmented_runtime` 结果，只能作为离线质量参考或最终修正候选，不能直接作为实时主干。
