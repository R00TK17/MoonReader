# MoonReader

纯 MoonBit 实现的文件内容读取库，支持 **TXT / CSV / JSON / JSONL / XML / Markdown / TAR** 七种格式，全程中文文件名友好（Windows 下 UTF-8 路径感知）。

## 快速开始

```moonbit nocheck
// 一键读取：按扩展名自动识别格式
let content = @moonreader.read("data/sample.csv")
match content {
  Table(rows) => for row in rows { ... }
  Lines(lines) => ...
  JsonValue(j) => ...
  JsonRows(js) => ...
  XmlDoc(root) => ...
  MarkdownBlocks(blocks) => ...
  TarFiles(names) => ...
}
```

## 统一入口

| 函数 | 说明 |
|------|------|
| `detect_format(path) -> FileFormat` | 按扩展名识别格式（`.txt`/`.csv`/`.json`/`.jsonl`/`.xml`/`.md`/`.tar`，不区分大小写，未知按 TXT） |
| `read(path) -> Content` | 自动分派，返回统一结果 |

`Content` 是一个带数据的枚举，按格式返回对应结构：

| 变体 | 对应格式 | 载荷类型 |
|------|----------|----------|
| `Lines` | TXT | `Array[String]`（按行） |
| `Table` | CSV | `Array[Array[String]]`（行 → 字段） |
| `JsonValue` | JSON | `Json`（动态值） |
| `JsonRows` | JSONL | `Array[Json]`（每行一个对象） |
| `XmlDoc` | XML | `XmlElement`（根元素树） |
| `MarkdownBlocks` | Markdown | `Array[MarkdownBlock]`（块结构） |
| `TarFiles` | TAR | `Array[String]`（包内文件名） |

## 各格式细粒度 API

```moonbit nocheck
// TXT
read_txt(path)            // 整个文件 → String
read_txt_by_line(path)    // → Array[String]
read_txt_by_byte(path)    // → Bytes（原始字节）
read_txt_by_block(path, n) // 每 n 个字符一块 → Array[String]

// CSV
read_csv_by_line(path)    // → Array[Array[String]]
read_csv_by_column(path)  // 转置 → Array[Array[String]]
read_csv_by_block(path, n)

// JSON / JSONL
read_json_dynamic(path)   // → Json
read_json_by_block(path, n)
read_jsonl_by_line(path)  // → Array[Json]

// XML
read_xml(path)            // → XmlElement（根元素树）
parse_xml(text)           // 解析字符串 → XmlElement

// Markdown
read_markdown(path)       // → Array[MarkdownBlock]（标题/段落/代码/引用/列表/水平线）
parse_markdown(text)      // 解析字符串 → Array[MarkdownBlock]

// TAR
read_tar_entries(path)           // 一次读盘，返回所有条目（TarEntry）
list_tar_filenames(path)         // 列出包内文件名
read_tar_file(path, inner)       // 读包内文件原始字节
read_tar_text(path, inner)       // 读包内文件并 UTF-8 解码
```

`read_tar_entries` 返回 `TarEntry` 数组（`name` 字段 + `content` 字节字段，另有 `text()` 方法解码为字符串），适合一次读取包内多个文件、避免反复读盘：

```moonbit nocheck
for e in @moonreader.read_tar_entries("data.tar") {
  println("\{e.name}: \{e.text()}")
}
```

## 错误处理

所有函数失败时抛出统一错误 `ReaderError`：

```moonbit nocheck
try {
  let j = @moonreader.read_json_dynamic("data.json")
} catch {
  Io(msg) => println("IO 错误: \{msg}")
  Parse(msg) => println("解析错误: \{msg}")
}
```

## CLI 演示

```bash
moon run cmd/main -- data/sample.csv
moon run cmd/main -- data/sample.tar            # 列出并 dump 包内文件
moon run cmd/main -- data/sample.tar alpha.txt  # 读取包内指定文件
```

## 中文文件名

库内部用 `_wfopen` + UTF-8 路径转换打开文件，外层路径和 tar 包内文件名均可为中文。
