# ASR 模型推荐结论

## 最终建议

- 保持 `qwen3-asr-0.6b-mlx-8bit` 作为当前默认实时 ASR 后端。
- 暂不把 `qwen3-asr-1.7b-mlx-8bit` 替换为默认实时后端。
- 暂不把 `mimo-v2.5-asr-mlx` 用作实时主干；仅保留为离线参考模型。
- 数字格式问题没有被任何候选模型充分解决，应进入单独的数字格式策略任务。

## 当前基线

`qwen3-asr-0.6b-mlx-8bit` 是当前实际使用的本地 ASR 基线。任何替换都必须同时满足质量、延迟、资源和产品路径要求。

## 结论口径

- 新默认实时后端：必须有 segmented 证据。
- 最终高质量修正模型：可以主要看 file-level 质量，但仍要看资源和等待时间。
- 离线质量参考：准确率可以很好，但不承担实时浮窗职责。

## Qwen3 0.6B segmented baseline

- CER: 0.0589
- WER: 0.0792
- RTF: 1.1845
- first partial latency: 1077.6 ms
- final latency: 184.5 ms
- max peak RSS: 1469.0 MB
- numeric pass rate: 0.2162

判断：当前综合最优实时默认后端。它不是所有单项指标第一，但在准确率、延迟、内存、CPU、长音频稳定性之间的平衡最好。

## Qwen3 1.7B segmented candidate

- CER: 0.0582
- WER: 0.0856
- RTF: 1.2404
- first partial latency: 1114.4 ms
- final latency: 335.3 ms
- max peak RSS: 2878.8 MB
- numeric pass rate: 0.2432

判断：不建议替代 0.6B 作为默认实时后端。它的 segmented CER 只比 0.6B 略低，但 WER 更高、RTF 更慢、首个 partial 更慢、final latency 明显更高，内存也约为 0.6B 的两倍。收益不足以抵消成本。

file-level CER 为 0.0577，略优于 0.6B file-level；因此 1.7B 可以保留为后续 final-only correction 候选，但本次没有足够证据把它设为默认。

## MiMo file-level candidate

- CER: 0.0928
- WER: 0.1144
- RTF: 0.1057
- max peak RSS: 7514.9 MB
- numeric pass rate: 0.2432

判断：不推荐作为实时主干，也不推荐作为默认最终修正模型。本次 file-level 总体 CER/WER 不优于 Qwen，长合成压力用例表现明显较差，资源占用更高，而且 segmented/chunked runtime 未被证明可用。

## 角色归类

| 模型 | 新默认实时 ASR 后端 | final-only correction 候选 | 离线质量参考 | 结论 |
|---|---|---|---|---|
| qwen3-asr-0.6b-mlx-8bit | 是，保持当前默认 | 可作为自身 final 输出 | 是 | 当前基线继续保留 |
| qwen3-asr-1.7b-mlx-8bit | 否 | 可以保留为后续候选 | 是 | 准确率收益不足以抵消延迟和资源成本 |
| mimo-v2.5-asr-mlx | 否 | 否，当前证据不足 | 是 | 仅离线参考；实时路径 unsupported |

## 下一步

- 不切换默认模型。
- 单独启动数字格式策略任务，因为最高 numeric pass rate 也只有约 24%。
- 如果后续继续评估 1.7B，应重点验证 final-only correction 的等待时间和是否真的改善用户文本，而不是把它直接接入实时 partial。
