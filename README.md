# any2pcd —— 文本/二进制点云转 PCD 工具(FasterEdge 点云工具)

用 Go 编写的点云格式转换器:把 **bin / 文本 / CSV / PCD** 点云文件转换为标准
**PCD v0.7**(PCL Point Cloud Data)文件。纯标准库实现,零第三方依赖。

与常见点云工具的关键差异:

- **保持时序**: 转换过程严格按输入点的**原始顺序**写出, 不做任何排序/去重/重排。
  带时间戳的雷达 bin(如 `x y z timestamp` 每点 4×float32)用
  `-fields "x,y,z,timestamp"` 即可把时间戳映射为 PCD 字段原样保留。
- **UTF-8 无 BOM**: 输出文件为 UTF-8(无 BOM)编码; PCD 内容为 ASCII 子集,
  不依赖系统 locale/编码集, 任何环境下解码一致。
- **自动探测**: 按扩展名与内容识别输入格式, 无需手动指定 `-from`。

## 支持清单

| 输入 | 说明 |
| --- | --- |
| `.bin` | 二进制点云, 每点 N×float32(little-endian)。自动尝试 3..16 个字段, 取第一个能整除文件大小的; KITTI 常见 4 字段自动命名为 `x y z intensity` |
| `.txt` / `.xyz` / 无扩展名 | 逐行空格/Tab 分隔数字, 自动列数命名(3→xyz, 4→xyz+intensity, 6→xyz+rgb, 7→xyz+intensity+rgb, 其余→featureN) |
| `.csv` | 逗号分隔(同文本) |
| `.pcd` | 已是 PCD 的文件(ASCII 或 binary, 仅支持 4 字节数值字段)——可做格式重编码, 如 binary→ascii、字段精简 |

## 用法

```
any2pcd [选项] [文件...]        # 转换文件, 缺省读标准输入
cat x.bin | any2pcd -from bin   # 从标准输入读取
```

| 选项 | 含义 |
| --- | --- |
| `-from 格式` | 输入格式: `auto`(默认)|`bin`|`text`|`csv`|`pcd` |
| `-fields 名称` | 字段名(逗号分隔), 如 `x,y,z,intensity` 或 `x,y,z,timestamp`; 也决定 bin 的每点字段数 |
| `-binary` | 输出二进制 PCD(`DATA binary`, little-endian float32, 体积最小) |
| `-output 文件` | 输出文件(仅单输入; 缺省标准输出) |
| `-outdir 目录` | 多输入时的输出目录(缺省 `.`, 输出 `<原名>.pcd`) |
| `-strict` | 严格模式: 出现 NaN/Inf/坏行/列数不一致即失败(exit 1) |
| `-skip-bad` | 跳过坏行(仅 text/csv; 默认失败) |
| `-version` | 打印版本 |

## 示例

```sh
# KITTI 风格 bin(x y z intensity)→ ASCII PCD
any2pcd velodyne_000001.bin > velodyne_000001.pcd

# 雷达 bin(x y z timestamp)→ 保留时间戳字段的 PCD(保持时序)
any2pcd -fields "x,y,z,timestamp" lidar_frame.bin > lidar_frame.pcd

# 二进制输出(文件更小, 解析更快)
any2pcd -binary lidar_frame.bin > lidar_frame_binary.pcd

# 文本点云 → PCD
any2pcd points.xyz > points.pcd

# CSV → PCD
any2pcd -from csv scan.csv > scan.pcd

# PCD binary 重编码为 ASCII
any2pcd -from pcd in_binary.pcd > out_ascii.pcd

# 多文件批量转换到目录
any2pcd -outdir ./out scan1.bin scan2.bin scan3.bin
```

## PCD 输出格式

```
# .PCD v0.7 - Point Cloud Data file format
VERSION 0.7
FIELDS x y z intensity
SIZE 4 4 4 4
TYPE F F F F
COUNT 1 1 1 1
WIDTH <点数>
HEIGHT 1
VIEWPOINT 0 0 0 1 0 0 0
POINTS <点数>
DATA ascii|binary
```

- 字段类型统一为 4 字节 `F`(float32)。
- ASCII 模式每行一个点、空格分隔, 值用最短无损表示(`%g`), 保证 float32 往返一致。
- binary 模式 body 为每点 N×4 字节 little-endian float32, 与常见 bin 读取端兼容。

## 约束

- 标准输入单次读入内存(点云数据量通常可控; 超大文件建议用文件输入, 内存按
  文件大小占用)。
- `-output` 仅限单输入; 多文件输出用 `-outdir`。
- PCD 输入仅支持 4 字节数值字段(`F`/`U`/`I`), 不支持 double/多 COUNT; 遇到
  double 字段请先用其它工具转换。
- 字段名仅允许 ASCII 字母/数字/下划线(PCD 规范兼容, 也保证 UTF-8 安全)。

## 构建

需要宿主机 Go 1.25+:

```sh
go build -trimpath -ldflags="-s -w" -o any2pcd .
go test ./...      # 单元测试(bin 往返/保序/无 BOM/字段映射/PCD 重编码)
```

随 FasterEdgeOS `OVERLAY_BUNDLES` 启用时可作为系统初始工具打包(离线升级可设
`ANY2PCD_SOURCE_DIR` 指向本地新版源码目录)。

## License

Apache-2.0(与 DontCrack 系列一致), 详见仓库 LICENSE。
