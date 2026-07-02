# LocalVoiceInput 全量本地 ASR 模型测评报告

## 范围

- Manifest case row：106
- 唯一音频文件：100
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
| mimo-v2.5-asr-mlx | file_level | 106 | 0.0928 | 0.1144 | 0.1057 | n/a | 3799.5 | 0.9538 |
| mimo-v2.5-asr-mlx | segmented | 106 | n/a | n/a | n/a | n/a | n/a | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | 106 | 0.0621 | 0.0813 | 0.0182 | n/a | 703.1 | 0.9850 |
| qwen3-asr-0.6b-mlx-8bit | segmented | 106 | 0.0589 | 0.0792 | 1.1845 | 1077.6 | 184.5 | 0.9891 |
| qwen3-asr-1.7b-mlx-8bit | file_level | 106 | 0.0577 | 0.0843 | 0.0350 | n/a | 1344.6 | 0.9893 |
| qwen3-asr-1.7b-mlx-8bit | segmented | 106 | 0.0582 | 0.0856 | 1.2404 | 1114.4 | 335.3 | 0.9896 |

## 总览：Deduplicated Audio Rollup

| 模型 | 模式 | unique-like cases | CER | WER | RTF | final latency ms | final coverage |
|---|---|---:|---:|---:|---:|---:|---:|
| mimo-v2.5-asr-mlx | file_level | 100 | 0.0973 | 0.1183 | 0.1054 | 3647.7 | 0.9510 |
| mimo-v2.5-asr-mlx | segmented | 100 | n/a | n/a | n/a | n/a | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | 100 | 0.0646 | 0.0817 | 0.0182 | 686.0 | 0.9840 |
| qwen3-asr-0.6b-mlx-8bit | segmented | 100 | 0.0612 | 0.0790 | 1.1872 | 180.2 | 0.9884 |
| qwen3-asr-1.7b-mlx-8bit | file_level | 100 | 0.0603 | 0.0851 | 0.0350 | 1307.6 | 0.9886 |
| qwen3-asr-1.7b-mlx-8bit | segmented | 100 | 0.0609 | 0.0862 | 1.2442 | 326.8 | 0.9889 |

## 分 Suite 结果

| 模型 | 模式 | suite | cases | CER | WER | RTF | peak RSS MB | peak CPU % | numeric pass |
|---|---|---|---:|---:|---:|---:|---:|---:|---:|
| qwen3-asr-0.6b-mlx-8bit | file_level | base | 10 | 0.0510 | 0.1898 | 0.0185 | 1435.2 | 95.1 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | numeric | 37 | 0.0169 | 0.0193 | 0.0196 | 1230.6 | 114.6 | 0.2162 |
| qwen3-asr-0.6b-mlx-8bit | file_level | extended_long | 3 | 0.0259 | 0.1252 | 0.0171 | 1405.3 | 99.6 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | long_prepared | 3 | 0.0153 | 0.0230 | 0.0174 | 1392.6 | 104.8 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | long_synthetic | 2 | 0.0851 | 0.1097 | 0.0243 | 2127.1 | 118.7 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | segment_budget | 10 | 0.0382 | 0.0382 | 0.0125 | 1623.2 | 109.1 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | segment_cache | 18 | 0.0811 | 0.0848 | 0.0179 | 1563.3 | 123.5 | n/a |
| qwen3-asr-0.6b-mlx-8bit | file_level | segment_cache_synthetic | 23 | 0.1417 | 0.1455 | 0.0182 | 1553.0 | 121.8 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | base | 10 | 0.0446 | 0.1740 | 0.0352 | 2810.0 | 85.8 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | numeric | 37 | 0.0207 | 0.0408 | 0.0368 | 2612.2 | 138.7 | 0.2432 |
| qwen3-asr-1.7b-mlx-8bit | file_level | extended_long | 3 | 0.0204 | 0.1239 | 0.0342 | 2777.8 | 121.9 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | long_prepared | 3 | 0.0089 | 0.0186 | 0.0345 | 2793.1 | 144.1 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | long_synthetic | 2 | 0.0185 | 0.0403 | 0.0430 | 3541.8 | 144.3 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | segment_budget | 10 | 0.0082 | 0.0082 | 0.0246 | 3067.1 | 148.7 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | segment_cache | 18 | 0.0771 | 0.0835 | 0.0354 | 2909.9 | 147.4 | n/a |
| qwen3-asr-1.7b-mlx-8bit | file_level | segment_cache_synthetic | 23 | 0.1374 | 0.1462 | 0.0357 | 2943.5 | 140.4 | n/a |
| mimo-v2.5-asr-mlx | file_level | base | 10 | 0.0311 | 0.1613 | 0.1159 | 7114.1 | 113.5 | n/a |
| mimo-v2.5-asr-mlx | file_level | numeric | 37 | 0.0243 | 0.0419 | 0.1083 | 7168.0 | 86.3 | 0.2432 |
| mimo-v2.5-asr-mlx | file_level | extended_long | 3 | 0.0186 | 0.0788 | 0.1106 | 7163.1 | 80.1 | n/a |
| mimo-v2.5-asr-mlx | file_level | long_prepared | 3 | 0.0151 | 0.0198 | 0.1105 | 7165.0 | 216.6 | n/a |
| mimo-v2.5-asr-mlx | file_level | long_synthetic | 2 | 0.8313 | 0.8352 | 0.0923 | 7514.9 | 170.2 | n/a |
| mimo-v2.5-asr-mlx | file_level | segment_budget | 10 | 0.1958 | 0.1958 | 0.0687 | 7284.4 | 78.8 | n/a |
| mimo-v2.5-asr-mlx | file_level | segment_cache | 18 | 0.0805 | 0.0829 | 0.1117 | 7252.7 | 84.6 | n/a |
| mimo-v2.5-asr-mlx | file_level | segment_cache_synthetic | 23 | 0.1503 | 0.1542 | 0.1083 | 7277.8 | 84.2 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | base | 10 | 0.0521 | 0.1944 | 1.1902 | 1325.1 | 83.1 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | numeric | 37 | 0.0169 | 0.0193 | 1.2314 | 1259.0 | 74.9 | 0.2162 |
| qwen3-asr-0.6b-mlx-8bit | segmented | extended_long | 3 | 0.0295 | 0.1406 | 1.1468 | 1351.3 | 85.9 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | long_prepared | 3 | 0.0153 | 0.0230 | 1.1329 | 1326.5 | 67.6 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | long_synthetic | 2 | 0.0251 | 0.0529 | 1.1699 | 1434.2 | 93.3 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | segment_budget | 10 | 0.0111 | 0.0111 | 1.1570 | 1427.5 | 49.6 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | segment_cache | 18 | 0.0801 | 0.0836 | 1.1280 | 1404.0 | 90.1 | n/a |
| qwen3-asr-0.6b-mlx-8bit | segmented | segment_cache_synthetic | 23 | 0.1399 | 0.1441 | 1.1757 | 1469.0 | 89.6 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | base | 10 | 0.0446 | 0.1762 | 1.2779 | 2724.1 | 123.7 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | numeric | 37 | 0.0207 | 0.0408 | 1.2863 | 2646.7 | 77.2 | 0.2432 |
| qwen3-asr-1.7b-mlx-8bit | segmented | extended_long | 3 | 0.0204 | 0.1313 | 1.1799 | 2751.4 | 140.9 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | long_prepared | 3 | 0.0089 | 0.0198 | 1.1756 | 2726.1 | 62.2 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | long_synthetic | 2 | 0.0226 | 0.0507 | 1.2125 | 2850.0 | 58.6 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | segment_budget | 10 | 0.0118 | 0.0118 | 1.1967 | 2878.8 | 82.1 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | segment_cache | 18 | 0.0773 | 0.0840 | 1.1934 | 2842.0 | 138.9 | n/a |
| qwen3-asr-1.7b-mlx-8bit | segmented | segment_cache_synthetic | 23 | 0.1380 | 0.1478 | 1.2251 | 2841.9 | 82.0 | n/a |
| mimo-v2.5-asr-mlx | segmented | base | 10 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | numeric | 37 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | extended_long | 3 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | long_prepared | 3 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | long_synthetic | 2 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | segment_budget | 10 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | segment_cache | 18 | n/a | n/a | n/a | n/a | n/a | n/a |
| mimo-v2.5-asr-mlx | segmented | segment_cache_synthetic | 23 | n/a | n/a | n/a | n/a | n/a | n/a |

## 排名与关键结论

### 整段文件级最终识别质量排名

按 raw manifest rollup 的 CER 从低到高排序。该排名只说明整段音频最终文本质量，不能单独证明实时产品可用。

| 排名 | 模型/模式 | CER | WER | RTF | final coverage |
|---:|---|---:|---:|---:|---:|
| 1 | qwen3-asr-1.7b-mlx-8bit / file_level | 0.0577 | 0.0843 | 0.0350 | 0.9893 |
| 2 | qwen3-asr-0.6b-mlx-8bit / file_level | 0.0621 | 0.0813 | 0.0182 | 0.9850 |
| 3 | mimo-v2.5-asr-mlx / file_level | 0.0928 | 0.1144 | 0.1057 | 0.9538 |

### 分段模拟实时产品体验排名

该排名只比较有 segmented 结果的实时候选。综合看 CER/WER、RTF、首个 partial、final latency 和内存占用。

| 排名 | 模型/模式 | CER | WER | RTF | first partial ms | final latency ms | max peak RSS MB | 判断 |
|---:|---|---:|---:|---:|---:|---:|---:|---|
| 1 | qwen3-asr-0.6b-mlx-8bit / segmented | 0.0589 | 0.0792 | 1.1845 | 1077.6 | 184.5 | 1469.0 | 当前最佳实时默认后端；准确率接近 1.7B，但延迟和资源更稳 |
| 2 | qwen3-asr-1.7b-mlx-8bit / segmented | 0.0582 | 0.0856 | 1.2404 | 1114.4 | 335.3 | 2878.8 | 不建议替代默认；CER 略低但 WER、延迟、RTF、内存均更差 |

MiMo-V2.5-ASR MLX 没有可用的 segmented/chunked runtime 证据，不能进入实时产品体验排名。

### 数字格式能力排名

数字格式通过率越高越好，但本次所有模型都处于低水平；这说明数字格式仍应作为独立后续策略处理。

| 排名 | 模型/模式 | numeric pass rate | 判断 |
|---:|---|---:|---|
| 1 | qwen3-asr-1.7b-mlx-8bit / file_level | 0.2432 | 最好但仍不可靠 |
| 2 | qwen3-asr-1.7b-mlx-8bit / segmented | 0.2432 | 仍不可靠 |
| 3 | mimo-v2.5-asr-mlx / file_level | 0.2432 | 仍不可靠 |
| 4 | qwen3-asr-0.6b-mlx-8bit / file_level | 0.2162 | 仍不可靠 |
| 5 | qwen3-asr-0.6b-mlx-8bit / segmented | 0.2162 | 仍不可靠 |

### 资源效率排名

这里优先看与产品路径相关的 segmented 资源；MiMo 只有 file-level 资源，因此单独列为离线参考成本。

| 排名 | 模型/模式 | mean peak RSS MB | max peak RSS MB | mean CPU % | 判断 |
|---:|---|---:|---:|---:|---|
| 1 | qwen3-asr-0.6b-mlx-8bit / segmented | 1374.6 | 1469.0 | 6.9 | 当前最适合常驻实时后端 |
| 2 | qwen3-asr-1.7b-mlx-8bit / segmented | 2782.6 | 2878.8 | 7.4 | 资源约为 0.6B 的两倍，不适合作为默认替代 |
| 3 | mimo-v2.5-asr-mlx / file_level | 7242.5 | 7514.9 | 28.7 | 离线成本高，且没有实时路径 |

### MiMo 分段实时兼容性

- MiMo segmented suite summary 均为 `unsupported_segmented_runtime`。
- 本地 runtime 检查到 file-level `generate(...)` 路径，但没有已证明安全可用的 `stream_transcribe`、`stream_generate` 或 `create_streaming_session` 产品接口。
- 因此 MiMo 不能推荐为新的默认实时 ASR 后端；本次只能作为离线质量参考。

## 最终解释

- `file_level` 只代表整段音频最终识别质量，不能单独证明适合作为实时语音输入后端。
- `segmented` 更接近 LocalVoiceInput 当前浮窗和长语音输入路线。
- Qwen3 1.7B 的 file-level CER 和 segmented CER 略好于 0.6B，但 WER、RTF、final latency 和内存成本更差；不足以替代当前默认。
- Qwen3 0.6B MLX 8-bit 仍是当前综合最优实时主干。
- MiMo 的整体 file-level CER/WER 不优于 Qwen，且没有 segmented 证据；保留为离线参考，不作为实时主干或默认最终修正模型。
- 数字格式通过率整体偏低，不能靠本次模型切换解决；应作为单独的数字格式策略任务处理。
