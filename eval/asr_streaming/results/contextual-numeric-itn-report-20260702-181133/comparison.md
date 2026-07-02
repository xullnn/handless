# Simple Numeric ITN Report

## Summary

| Condition | Passed | Total | Pass rate |
|---|---:|---:|---:|
| Raw ASR final text | 8 | 37 | 21.6% |
| NumericITN final text | 23 | 37 | 62.2% |
| Delta | +15 | - | 40.5% |

- Improved cases: `15`
- Worsened cases: `0`
- Still failing cases: `14`

CER/WER are not recomputed in this report. Numeric-format pass rate is the primary ITN metric because the reference text is spoken-form Chinese.

## Improved Cases

| Case | Raw final | ITN final |
|---|---|---|
| `numeric_decimal_001` | 这个版本的实时因子是零点二零八。 | 这个版本的实时因子是0.208。 |
| `numeric_decimal_002` | 模型大小大约是零点六B。 | 模型大小大约是0.6B。 |
| `numeric_digits_001` | 订单编号是一二三四五六。 | 订单编号是123456。 |
| `numeric_digits_002` | 验证码是八零六二一九。 | 验证码是806219。 |
| `numeric_digits_003` | 测试编号是零零七三二。 | 测试编号是00732。 |
| `numeric_digits_004` | 这批样本的编号从一零零一开始。 | 这批样本的编号从1001开始。 |
| `numeric_index_003` | 我们先处理 case 零三。 | 我们先处理 case 03。 |
| `numeric_mixed_003` | MLX版本模型大小接近零点九四GB。 | MLX版本模型大小接近0.94GB。 |
| `numeric_mixed_004` | CER是零点零七五八，WER是零点二二三六。 | CER是0.0758，WER是0.2236。 |
| `numeric_percent_001` | 这次错误率下降了百分之三点五。 | 这次错误率下降了3.5%。 |
| `numeric_percent_002` | 准确率提升到百分之九十二点八。 | 准确率提升到92.8%。 |
| `numeric_unit_001` | 这台电脑有四十八GB内存。 | 这台电脑有48GB内存。 |
| `numeric_unit_002` | 模型文件大约占用九百六十四 MB。 | 模型文件大约占用964MB。 |
| `numeric_unit_003` | 这个服务监听一八一零五端口。 | 这个服务监听18105端口。 |
| `numeric_version_001` | 当前版本是一点二点三。 | 当前版本是1.2.3。 |
