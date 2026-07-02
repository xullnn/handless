# ASR 模型推荐结论

## 当前基线

`qwen3-asr-0.6b-mlx-8bit` 是当前实际使用的本地 ASR 基线。任何替换都必须同时满足质量、延迟、资源和产品路径要求。

## 结论口径

- 新默认实时后端：必须有 segmented 证据。
- 最终高质量修正模型：可以主要看 file-level 质量，但仍要看资源和等待时间。
- 离线质量参考：准确率可以很好，但不承担实时浮窗职责。

## Qwen3 0.6B segmented baseline

- CER: 0.1053
- WER: 0.1053
- RTF: 1.2693
- first partial latency: 1086.8 ms
- final latency: 147.2 ms

## Qwen3 1.7B segmented candidate

- CER: 0.1053
- WER: 0.1053
- RTF: 1.3558
- first partial latency: 1124.3 ms
- final latency: 256.5 ms

是否替代 0.6B 需要比较它相对 baseline 的准确率提升是否足以抵消更高资源和延迟成本。

## MiMo file-level candidate

- CER: 0.0000
- WER: 0.0000
- RTF: 0.2102

MiMo 只有在 segmented/chunked 路线被证明可用时，才可能成为实时主干；否则只能作为离线质量参考或最终修正候选。

## 待最终人工确认

完成全量运行后，需要根据 `comparison.md` 的完整表格确认：

- 哪个模型准确率最好。
- 哪个模型数字格式最好。
- 哪个模型 realtime segmented 体验最好。
- 哪个模型资源消耗最低。
- 是否存在足够证据切换默认模型。
