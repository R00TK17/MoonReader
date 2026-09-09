# MoonReader

纯 MoonBit 实现的文件内容读取库，支持 **TXT / CSV / JSON / JSONL / XML / Markdown / ZIP / TAR / DOCX / XLSX / PPTX / PDF** 十二种格式，全程中文文件名友好（Windows 下 UTF-8 路径感知）。

> **定位**：面向信创 / 国产化场景，纯 MoonBit 实现多类型文件内容读取。

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
  ZipFiles(entries) => ...
  TarFiles(entries) => ...
  DocxText(text) => ...
  ExcelSheets(sheets) => ...
  PptxSlides(slides) => ...
  PdfPages(pages) => ...
}
```

## 统一入口

| 函数 | 说明 |
|------|------|
| `detect_format(path) -> FileFormat` | 按扩展名识别格式（`.txt`/`.csv`/`.json`/`.jsonl`/`.xml`/`.md`/`.zip`/`.tar`/`.docx`/`.xlsx`/`.pptx`/`.pdf`，不区分大小写，未知按 TXT） |
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
| `ZipFiles` | ZIP | `Array[ZipEntry]`（包内条目：文件名 + 内容字节） |
| `TarFiles` | TAR | `Array[TarEntry]`（包内条目：文件名 + 内容字节） |
| `DocxText` | DOCX | `String`（文档全部文本） |
| `ExcelSheets` | XLSX | `Array[ExcelSheet]`（全部工作表） |
| `PptxSlides` | PPTX | `Array[String]`（每页文本） |
| `PdfPages` | PDF | `Array[String]`（每页文本） |

## 各格式细粒度 API

```moonbit nocheck
// TXT
read_txt(path)            // 整个文件 → String
read_txt_by_line(path)    // → Array[String]
read_txt_by_byte(path)    // → Bytes（原始字节）
read_txt_by_block(path, n) // 每 n 行一块 → Array[String]

// 通用文件字节读写（任意格式，中文文件名友好）
read_file_to_bytes(path)        // 读文件原始字节 → Bytes
write_file_to_bytes(path, data) // 写字节到文件（覆盖写）

// CSV
read_csv_by_line(path)    // → Array[Array[String]]
read_csv_by_column(path)  // 转置 → Array[Array[String]]
read_csv_by_block(path, n)

// JSON / JSONL
read_json(path)           // → Json
read_json_by_block(path, n)
read_jsonl_by_line(path)  // → Array[Json]

// XML
read_xml(path)            // → XmlElement（根元素树）
parse_xml(text)           // 解析字符串 → XmlElement

// Markdown
read_markdown(path)       // → Array[MarkdownBlock]（标题/段落/代码/引用/列表/水平线）
parse_markdown(text)      // 解析字符串 → Array[MarkdownBlock]

// ZIP（解压基于 hustcer/fzip）
read_zip_entries(path)           // 一次读盘，返回所有条目（ZipEntry）
list_zip_filenames(path)         // 列出包内文件名
read_zip_file(path, inner)       // 读包内文件原始字节
read_zip_text(path, inner)       // 读包内文件并 UTF-8 解码

// TAR
read_tar_entries(path)           // 一次读盘，返回所有条目（TarEntry）
list_tar_filenames(path)         // 列出包内文件名
read_tar_file(path, inner)       // 读包内文件原始字节
read_tar_text(path, inner)       // 读包内文件并 UTF-8 解码

// Office（OOXML，内部解压基于 hustcer/fzip + XML 解析）
read_docx_text(path)             // Word 全部文本 → String
read_docx_paragraphs(path)       // Word 各段文本 → Array[String]
read_excel_sheets(path)          // Excel 全部工作表 → Array[ExcelSheet]（name + rows）
read_excel_sheet_rows(path, i)   // Excel 第 i 个工作表 → Array[Array[String]]（行 → 单元格）
read_excel_sheet_text(path, i)   // Excel 第 i 个工作表 → String（制表符/换行分隔）
read_excel_first_sheet_rows(path) // Excel 第一个工作表 → Array[Array[String]]
read_excel_first_sheet_text(path) // Excel 第一个工作表 → String
read_pptx_text(path)             // PPT 全部文本 → String
read_pptx_text_by_slide(path)    // PPT 每页文本 → Array[String]
read_pdf_text(path)              // PDF 全部文本 → String
read_pdf_text_by_page(path)      // PDF 每页文本 → Array[String]
```

`read_tar_entries` 返回 `TarEntry` 数组（`name` 字段 + `content` 字节字段，另有 `text()` 方法解码为字符串），适合一次读取包内多个文件、避免反复读盘：

```moonbit nocheck
for e in @moonreader.read_tar_entries("data.tar") {
  println("\{e.name}: \{e.text()}")
}
```

## 编码检测与转换

文本类格式（TXT / CSV / JSON / JSONL / XML / Markdown，以及 ZIP / TAR 内层文本）默认**自动检测编码**，也可显式指定 `encoding` 参数：

```moonbit nocheck
// 自动检测：BOM → UTF-32/16 零字节模式 → UTF-8 严格校验 → GBK/Big5 启发式 → Latin-1
read_txt("data/老数据.txt")                          // 老系统导出的 GBK 文件直接读出中文

// 显式指定：GBK 与 Big5 字节层面无法可靠区分，繁体需显式 big5
read_txt("data/繁体.txt", encoding=Some(Encoding::Big5))
read_csv_by_line("data.csv", encoding=Some(Encoding::Gbk))
```

### 检测 / 解码 / 编码 / 转换

| 函数 | 说明 |
|------|------|
| `detect_encoding(bytes) -> Encoding` | 探测字节流编码 |
| `parse_encoding("gbk") -> Encoding?` | 编码名 → 枚举（别名：`gbk`/`gb2312`/`cp936`/`gb18030`、`big5`/`cp950`、`utf-8`/`utf-16`/`utf-16le`/`utf-16be`/`utf-32`/`latin1` 等） |
| `decode(bytes, encoding) -> String` | 按指定编码解码为 UTF-8 字符串 |
| `decode_auto(bytes) -> String` | 自动检测并解码 |
| `encode(text, encoding, bom?=false) -> Bytes` | 编码为指定编码字节 |
| `convert(bytes, from, to) -> Bytes` | 任意两种编码互转（= `encode(decode(...))`） |

```moonbit nocheck
// 任意编码互转：GBK 老数据 → UTF-8 字节 → 写回新文件（支持中文文件名）
let gbk = @moonreader.read_txt_by_byte("data/老数据.csv")
let utf8 = @moonreader.convert(gbk, Encoding::Gbk, Encoding::Utf8)
@moonreader.write_file_to_bytes("data/新数据.csv", utf8)
```

`Encoding` 枚举：`Utf8 / Utf16Le / Utf16Be / Utf32Le / Utf32Be / Gbk / Big5 / Latin1`。编码时不可映射字符（如 emoji、生僻字转 GBK）替换为 `?`（0x3F）。

## 错误处理

所有函数失败时抛出统一错误 `ReaderError`：

```moonbit nocheck
try {
  let j = @moonreader.read_json("data.json")
} catch {
  Io(msg) => println("IO 错误: \{msg}")
  Parse(msg) => println("解析错误: \{msg}")
}
```

## CLI 演示

```bash
moon run cmd/main -- testdata/sample.csv
moon run cmd/main -- testdata/sample.zip            # 列出并 dump 包内文件
moon run cmd/main -- testdata/sample.zip sample.txt # 读取包内指定文件
moon run cmd/main -- testdata/sample.tar            # 列出并 dump 包内文件
moon run cmd/main -- testdata/sample.tar alpha.txt  # 读取包内指定文件
moon run cmd/main -- testdata/sample.docx           # 读取 Word 文档文本
moon run cmd/main -- testdata/sample.xlsx           # 读取 Excel 表格
moon run cmd/main -- testdata/sample.pptx           # 读取 PPT 每页文本
moon run cmd/main -- testdata/sample.pdf            # 读取 PDF 每页文本

# 编码转换：convert <文件> <目标编码> [源编码] [输出路径]
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8            # 自动检测源编码，覆盖写回
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk        # 显式源编码
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk 新.txt # 另存为新文件
```

### Wasm-GC CLI 模式（浏览器 / IDE 预览）

同一套 CLI 可编译到 `wasm-gc` 目标运行：文件读写委托给 `moonbitlang/x/fs`（底层走 moonrun 的 `__moonbit_fs_unstable` 宿主），路径以字符串交给宿主，中文文件名天然支持，编码自动检测（GBK / Big5 等）同样生效。

```bash
moon run --target wasm-gc cmd/main -- testdata/sample.csv
moon run --target wasm-gc cmd/main -- testdata/中文.txt
moon run --target wasm-gc cmd/main -- testdata/encoding_gbk.txt
moon run --target wasm-gc cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk 新.txt
```

## 中文文件名

库内部用 `_wfopen` + UTF-8 路径转换打开文件，外层路径和 zip/tar 包内文件名均可为中文。
