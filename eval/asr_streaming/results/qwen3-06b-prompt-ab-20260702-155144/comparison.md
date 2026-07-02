# Qwen3 0.6B Prompt vs No-Prompt A/B Report

## 结论

- 不建议把当前数字风格系统提示词默认开启。
- 提示词确实改善了一部分数字格式，但绝对通过率仍然很低。
- 基础识别没有明显质量回退，但首个 partial 延迟明显增加。
- 数字格式问题仍应优先进入本地 ITN / 数字规整后处理路线。

## 测试对象

- 模型：`qwen3-asr-0.6b-mlx-8bit`
- 路线：segmented simulated realtime
- 提示词文件：`configs/asr/qwen3_system_prompt.numeric_style.zh.txt`
- 主测试：`cases.numeric.local.jsonl` 37 条
- 回归护栏：`cases.local.jsonl` 10 条

## 数字格式结果

| 条件 | 通过数 | 总数 | 通过率 |
|---|---:|---:|---:|
| no-prompt | 8 | 37 | 21.6% |
| prompt | 13 | 37 | 35.1% |
| delta | +5 | - | 13.5% |

- 改善 case 数：`5`
- 变差 case 数：`0`

注意：numeric suite 的 CER/WER 是按口语参考文本计算的，所以当提示词把“零点二零八”改成 `0.208` 时，CER/WER 可能上升。这里数字格式通过率是主指标。

## 数字 Suite 延迟与质量信号

| 条件 | CER | WER | first partial |
|---|---:|---:|---:|
| no-prompt | 0.0169 | 0.0193 | 1076.8 ms |
| prompt | 0.0931 | 0.1023 | 2442.2 ms |
| delta | 0.0761 | 0.0830 | 1365.4 ms |

## 基础识别回归护栏

| 条件 | CER | WER | first partial |
|---|---:|---:|---:|
| no-prompt | 0.0521 | 0.1944 | 1085.5 ms |
| prompt | 0.0503 | 0.1585 | 1636.2 ms |
| delta | -0.0018 | -0.0359 | 550.6 ms |

- 基础 suite 回归数：`0`

## 改善样例

| case | no-prompt | prompt |
|---|---|---|
| `numeric_digits_002` | 验证码是八零六二一九。 | 验证码是 806219。 |
| `numeric_digits_004` | 这批样本的编号从一零零一开始。 | 这批样本的编号从 1001 开始。 |
| `numeric_decimal_001` | 这个版本的实时因子是零点二零八。 | 这个版本的实时因子是 0.208。 |
| `numeric_unit_003` | 这个服务监听一八一零五端口。 | 这个服务监听 18105 端口。 |
| `numeric_version_001` | 当前版本是一点二点三。 | 当前版本是 1.2.3。 |

## 变差样例

- 无

## 推荐

- 状态：`do_not_enable_prompt_by_default`
- 数字格式通过率有提升，但绝对通过率仍然偏低。
- 提示词明显增加 numeric 和 base 两个 suite 的首个 partial 延迟。
- 基础 suite 的 CER/WER 没有回退，因此提示词可以保留为实验依据，但不适合作为默认产品路径。
- 下一步：先实现保守的本地数字 ITN / 后处理层，再考虑是否需要默认提示词。
