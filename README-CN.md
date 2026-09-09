# MoonReader

纯 MoonBit 实现的文件内容读取库，支持 **12 种格式** —— TXT / CSV / JSON / JSONL / XML / Markdown / ZIP / TAR / DOCX / XLSX / PPTX / PDF，全程 **中文文件名友好**（Windows 下 UTF-8 路径感知），并内置 **编码自动检测**（UTF-8 / UTF-16 / UTF-32 / GBK / Big5 / Latin-1）。


```text
包名：  R00TK17/moonreader
目标：  native · llvm · wasm-gc
协议：  Apache-2.0
```

---

## 使用本项目

MoonReader 既是一个库，也是一个可直接运行的项目。`cmd/main` 包是一个 CLI 演示程序，会针对 `testdata/` 里的样例逐一跑通所有格式。

### 环境要求

- [MoonBit](https://www.moonbitlang.com/) 工具链（`moon` 命令）。本项目基于 `0.1.20260827` 开发。

### 构建

```bash
moon update                    # 首次拉取依赖（hustcer/fzip、moonbitlang/x）
moon build                     # native 目标
moon build --target wasm-gc    # 浏览器 / IDE 预览目标
```

### 测试

```bash
moon test
```

### 运行 CLI 演示

```bash
moon run cmd/main -- testdata/sample.csv              # CSV
moon run cmd/main -- testdata/中文.txt                 # 中文文件名 TXT
moon run cmd/main -- testdata/sample.json             # JSON
moon run cmd/main -- testdata/sample.jsonl            # JSONL
moon run cmd/main -- testdata/sample.xml              # XML
moon run cmd/main -- testdata/sample.md               # Markdown
moon run cmd/main -- testdata/sample.zip              # 列出并 dump ZIP 条目
moon run cmd/main -- testdata/sample.zip sample.txt   # 读取包内指定文件
moon run cmd/main -- testdata/sample.tar              # 列出并 dump TAR 条目
moon run cmd/main -- testdata/sample.tar alpha.txt    # 读取包内指定文件
moon run cmd/main -- testdata/sample.docx             # Word
moon run cmd/main -- testdata/sample.xlsx             # Excel
moon run cmd/main -- testdata/sample.pptx             # PowerPoint
moon run cmd/main -- testdata/sample.pdf              # PDF

# 编码转换：convert <文件> <目标编码> [源编码] [输出路径]
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8            # 自动检测源编码，覆盖写回
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk        # 显式源编码
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk out.txt # 另存为新文件
```

### wasm-gc 下运行

同一套 CLI 可编译到 `wasm-gc`（文件读写委托给 `moonbitlang/x/fs`，中文文件名与编码检测照常生效）：

```bash
moon run --target wasm-gc cmd/main -- testdata/sample.csv
moon run --target wasm-gc cmd/main -- testdata/中文.txt
moon run --target wasm-gc cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk out.txt
```

### 目录结构

```text
cmd/main/                  CLI 演示（可执行）
    main.mbt               参数解析 + 按扩展名分派打印
    moon.pkg               可执行包配置

*.mbt  库本体（每种格式一个文件）
    reader.mbt             统一入口 read() + Content 枚举
    format.mbt             FileFormat 枚举 + detect_format()
    error.mbt              ReaderError 错误类型
    txt.mbt                TXT 与通用字节读写（read_file_to_bytes / write_file_to_bytes）
    csv.mbt                CSV
    json.mbt               JSON / JSONL
    xml.mbt                XML 解析器 + XmlElement 树遍历
    markdown.mbt           Markdown 块级解析
    zip.mbt                ZIP（基于 hustcer/fzip）
    tar.mbt                TAR
    office.mbt             DOCX / XLSX / PPTX（OOXML）
    pdf.mbt                PDF 文本抽取
    encoding.mbt           编码检测 / 解码 / 编码 / 转换
    gbk_table.mbt          GBK 解码码表
    gbk_enc_table.mbt      GBK 编码码表
    big5_table.mbt         Big5 解码码表
    big5_enc_table.mbt     Big5 编码码表

fs_utf8.c                 native 文件 I/O 的 C stub（_wfopen，UTF-8 路径感知）
fs_utf8_native.mbt        native / llvm 的文件 I/O（走 C stub）
fs_utf8_wasm.mbt          wasm-gc 的文件 I/O（委托给 @fs）

testdata/                 样例：12 种格式 + 中文文件名 + 编码样例
moonreader_test.mbt       黑盒测试（对公开 API）
moonreader_wbtest.mbt     白盒测试（对内部实现）
moon.pkg                  包配置（导入 + 按目标选择文件）
moon.mod                  包元数据
LICENSE                   Apache-2.0
README.md / README-CN.md  完整使用文档（英文 / 中文）
README.mbt.md             MoonBit 包页 README（精简）
```

---

## 依赖

库本体用 MoonBit 编写。压缩包解压委托给第三方包（均为纯 MoonBit，无 C FFI）：

| 包 | 版本 | 用途 |
|---|---|---|
| `hustcer/fzip` | `0.8.6` | ZIP / DEFLATE 解压 —— 支撑 **ZIP**，以及 **DOCX / XLSX / PPTX / PDF**（OOXML 压缩包与 PDF 的 `FlateDecode` 流） |
| `moonbitlang/x` | `0.5.1` | wasm-gc 目标下的 `@fs` 文件读写 |

其余部分——TXT / CSV / JSON / JSONL / XML / Markdown / TAR、编码检测与转换，以及 PDF / XLSX / PPTX / DOCX 的结构解析——均在本仓库内直接实现。

`moonbitlang/core`（json / debug / base64 / utf8 / utf16 / ref）是标准库，始终可用。

---

## 安装

包已发布到 [mooncakes.io](https://mooncakes.io/docs/R00TK17/moonreader)，直接加入你的项目：

```bash
moon add R00TK17/moonreader
```

然后在你的 `moon.pkg` 中导入：

```moonbit
import {
  "R00TK17/moonreader",
}
```

所有 API 都在扁平的 `@moonreader` 命名空间下，一次导入即可全部使用。

---

## 快速开始

调用 `read(path)`，按扩展名自动识别格式并返回强类型结果：

```moonbit
let content = @moonreader.read("data/sample.csv")

match content {
  @moonreader.Content::Table(rows) => {
    // CSV → 二维数组（行 → 字段）
    for row in rows {
      println(row.join(" | "))
    }
  }
  @moonreader.Content::Lines(lines) => println(lines.join("\n"))
  @moonreader.Content::JsonValue(j) => println(j.stringify(indent=2))
  @moonreader.Content::XmlDoc(root) => println(root.to_string())
  @moonreader.Content::PdfPages(pages) => println(pages.join("\n---\n"))
  _ => println("其它格式")
}
```

> `read` 返回 `Content` 枚举，按格式 match 得到对应结构。在 `match` 内部，构造器也可不加前缀直接写（如 `Table(rows)`、`Lines(lines)`），因为被匹配值的类型已知。

---

## 统一入口

| 函数 | 说明 |
|---|---|
| `detect_format(path : String) -> FileFormat` | 按扩展名识别格式（`.txt` `.csv` `.json` `.jsonl` `.xml` `.md` `.zip` `.tar` `.docx` `.xlsx` `.pptx` `.pdf`，不区分大小写；未知按 `Txt`） |
| `read(path : String) -> Content raise ReaderError` | 自动分派，返回统一结果 |

### `Content` 变体

| 变体 | 格式 | 载荷 |
|---|---|---|
| `Lines` | TXT | `Array[String]`（按行） |
| `Table` | CSV | `Array[Array[String]]`（行 → 字段） |
| `JsonValue` | JSON | `Json`（动态值） |
| `JsonRows` | JSONL | `Array[Json]`（每行一个对象） |
| `XmlDoc` | XML | `XmlElement`（根元素树） |
| `MarkdownBlocks` | Markdown | `Array[MarkdownBlock]` |
| `ZipFiles` | ZIP | `Array[ZipEntry]`（文件名 + 内容字节） |
| `TarFiles` | TAR | `Array[TarEntry]`（文件名 + 内容字节） |
| `DocxText` | DOCX | `String`（文档全部文本） |
| `ExcelSheets` | XLSX | `Array[ExcelSheet]`（全部工作表） |
| `PptxSlides` | PPTX | `Array[String]`（每页文本） |
| `PdfPages` | PDF | `Array[String]`（每页文本） |

### `FileFormat` 变体

`Txt · Csv · Json · Jsonl · Xml · Markdown · Zip · Tar · Docx · Xlsx · Pptx · Pdf`

```moonbit
if @moonreader.detect_format("报告.PDF") == @moonreader.FileFormat::Pdf {
  // ...
}
```

---

## 错误处理

所有可能失败的函数都抛出统一错误类型 `ReaderError`：

```moonbit
try {
  let j = @moonreader.read_json("data.json")
} catch {
  Io(msg) => println("IO 错误: \{msg}")
  Parse(msg) => println("解析错误: \{msg}")
}
```

- `ReaderError::Io(String)` —— 文件打不开 / 读不了 / 写不了。
- `ReaderError::Parse(String)` —— 内容解析失败。

---

## 文本（TXT）与通用字节读写

```moonbit
@moonreader.read_txt("a.txt")                  // String（编码自动检测）
@moonreader.read_txt_by_line("a.txt")          // Array[String]
@moonreader.read_txt_by_byte("a.txt")          // Bytes（原始字节）
@moonreader.read_txt_by_block("a.txt", 1024)   // Array[String]，每块 1024 行

// 显式指定编码
@moonreader.read_txt("a.txt", encoding=Some(@moonreader.Encoding::Gbk))
```

通用字节级文件读写（任意格式、中文文件名友好）：

```moonbit
let raw : Bytes = @moonreader.read_file_to_bytes("data/blob.bin")
@moonreader.write_file_to_bytes("data/out.bin", raw)   // 覆盖写
```

---

## CSV

```moonbit
let rows = @moonreader.read_csv_by_line("data.csv")        // Array[Array[String]]
let cols = @moonreader.read_csv_by_column("data.csv")      // 转置（列 → 值）
let blks = @moonreader.read_csv_by_block("data.csv", 100)  // Array[Array[Array[String]]]
```

---

## JSON / JSONL

`read_json` 返回 `Json`（来自 `moonbitlang/core/json`），可用 `.stringify()`、`[字段]` 等。调用这些方法前，需在 `moon.pkg` 里同时导入 `moonbitlang/core/json`。

```moonbit
let j = @moonreader.read_json("data.json")       // Json
println(j.stringify(indent=2))

let js = @moonreader.read_jsonl_by_line("data.jsonl")     // Array[Json]
let blocks = @moonreader.read_json_by_block("data.json", 50) // Array[Array[Json]]
```

---

## XML

解析文件，或直接解析字符串。用 `XmlElement` 的方法遍历树：

```moonbit
let root = @moonreader.read_xml("data.xml")       // XmlElement
// 或: @moonreader.parse_xml("<r><a>hi</a></r>")

root.name                    // String
root.attrs                   // Array[(String, String)]
root.text()                  // String：全部后代文本
root.attr("id")              // String?
root.to_string()             // String：带缩进的 XML

root.child_elements()        // Array[XmlElement]：直接子元素
root.find("item")            // XmlElement?：第一个名为 item 的后代
root.find_all("item")        // Array[XmlElement]：所有名为 item 的后代
```

---

## Markdown

```moonbit
let blocks = @moonreader.read_markdown("README.md")  // Array[MarkdownBlock]
// 或: @moonreader.parse_markdown("# 标题\n\n- 一\n- 二\n")

for b in blocks {
  println(b.to_string())
}
```

`MarkdownBlock` 变体：`Heading(Int, String) · Paragraph(String) · CodeBlock(String, String) · Quote(String) · ListItem(String) · HorizontalRule`。

---

## ZIP

ZIP 解压由纯 MoonBit 的 `hustcer/fzip` 提供。

```moonbit
let entries = @moonreader.read_zip_entries("a.zip")   // Array[ZipEntry]（文件名 + 内容）
@moonreader.list_zip_filenames("a.zip")               // Array[String]
@moonreader.read_zip_file("a.zip", "inner.txt")       // Bytes（原始）
@moonreader.read_zip_text("a.zip", "inner.txt")       // String（编码自动检测）

for e in entries {
  println("\{e.name} → \{e.text()}")   // e.text() 自动检测编码解码
}
```

`ZipEntry` 字段：`name : String`，`content : Bytes`。

---

## TAR

```moonbit
let entries = @moonreader.read_tar_entries("a.tar")   // Array[TarEntry]
@moonreader.list_tar_filenames("a.tar")               // Array[String]
@moonreader.read_tar_file("a.tar", "inner.txt")       // Bytes
@moonreader.read_tar_text("a.tar", "inner.txt")       // String

for e in entries {
  println("\{e.name} → \{e.text()}")
}
```

`TarEntry` 字段：`name : String`，`content : Bytes`。

---

## Office（OOXML）

```moonbit
// DOCX
@moonreader.read_docx_text("a.docx")            // String（全部段落）
@moonreader.read_docx_paragraphs("a.docx")      // Array[String]

// XLSX
@moonreader.read_excel_sheets("a.xlsx")         // Array[ExcelSheet]（名称 + 行）
@moonreader.read_excel_sheet_rows("a.xlsx", 1)  // Array[Array[String]] —— 第 1 个工作表
@moonreader.read_excel_sheet_text("a.xlsx", 1)  // String —— 第 1 个工作表
@moonreader.read_excel_first_sheet_rows("a.xlsx")  // 第一个工作表 → 二维数组
@moonreader.read_excel_first_sheet_text("a.xlsx")  // 第一个工作表 → String

// PPTX
@moonreader.read_pptx_text("a.pptx")            // String（全部页）
@moonreader.read_pptx_text_by_slide("a.pptx")   // Array[String]（每页）
```

`ExcelSheet` 字段：`name : String`，`rows : Array[Array[String]]`。

---

## PDF

```moonbit
@moonreader.read_pdf_text("a.pdf")             // String（全部页）
@moonreader.read_pdf_text_by_page("a.pdf")     // Array[String]（每页）
```

---

## 编码检测与转换

文本类格式（TXT / CSV / JSON / JSONL / XML / Markdown，以及 ZIP / TAR 内层文件）**默认自动检测编码**，也可用 `encoding=` 显式指定。

| 函数 | 说明 |
|---|---|
| `detect_encoding(bytes) -> Encoding` | 探测字节流编码 |
| `parse_encoding(name) -> Encoding?` | 编码名 → 枚举（别名：`gbk`/`gb2312`/`cp936`/`gb18030`、`big5`/`cp950`、`utf-8`、`utf-16`/`utf-16le`/`utf-16be`、`utf-32`、`latin1`） |
| `decode(bytes, encoding) -> String` | 按指定编码解码 |
| `decode_auto(bytes) -> String` | 自动检测并解码 |
| `encode(text, encoding, bom?=false) -> Bytes` | 编码为指定编码字节 |
| `convert(bytes, from, to) -> Bytes` | 任意两种编码互转 |

`Encoding` 变体：`Utf8 · Utf16Le · Utf16Be · Utf32Le · Utf32Be · Gbk · Big5 · Latin1`。

```moonbit
// GBK 老数据 → UTF-8 字节 → 写回（中文文件名可用）
let gbk  = @moonreader.read_file_to_bytes("data/老数据.csv")
let utf8 = @moonreader.convert(gbk, @moonreader.Encoding::Gbk, @moonreader.Encoding::Utf8)
@moonreader.write_file_to_bytes("data/新数据.csv", utf8)

// 自动检测 vs 显式指定
@moonreader.read_txt("data/老数据.txt")                                     // 自动识别 GBK
@moonreader.read_txt("data/繁体.txt", encoding=Some(@moonreader.Encoding::Big5))
```

> **注意：** GBK 与 Big5 在字节层面无法可靠区分，自动检测遇到双字节序列默认按 GBK。繁体中文请显式 `encoding=Some(Encoding::Big5)`。

---

## 中文文件名

native 后端在 Windows 上先把路径转成 UTF-8 再用 `_wfopen` 打开，因此外层路径、以及 zip/tar 包内文件名都可以是中文。wasm-gc 下路径以字符串交给宿主，天然 UTF-8。

---

## 目标支持

| 目标 | 文件 I/O 后端 |
|---|---|
| `native` / `llvm` | C stub（`fs_utf8.c`），走 `_wfopen` |
| `wasm-gc` | 委托给 `moonbitlang/x/fs` |

各目标的公开 API 完全一致。`js` 与 `wasm`（WASI）暂未接入。

---

## 完整 API 索引

| 函数 | 返回 |
|---|---|
| `detect_format(path)` | `FileFormat` |
| `read(path)` | `Content` |
| `read_txt(path, encoding?)` | `String` |
| `read_txt_by_line(path, encoding?)` | `Array[String]` |
| `read_txt_by_byte(path)` | `Bytes` |
| `read_txt_by_block(path, n, encoding?)` | `Array[String]` |
| `read_file_to_bytes(path)` | `Bytes` |
| `write_file_to_bytes(path, data)` | `Unit` |
| `read_csv_by_line(path, encoding?)` | `Array[Array[String]]` |
| `read_csv_by_column(path, encoding?)` | `Array[Array[String]]` |
| `read_csv_by_block(path, n, encoding?)` | `Array[Array[Array[String]]]` |
| `read_json(path, encoding?)` | `Json` |
| `read_json_by_block(path, n, encoding?)` | `Array[Array[Json]]` |
| `read_jsonl_by_line(path, encoding?)` | `Array[Json]` |
| `read_xml(path, encoding?)` | `XmlElement` |
| `parse_xml(text)` | `XmlElement` |
| `read_markdown(path, encoding?)` | `Array[MarkdownBlock]` |
| `parse_markdown(text)` | `Array[MarkdownBlock]` |
| `read_zip_entries(path)` | `Array[ZipEntry]` |
| `list_zip_filenames(path)` | `Array[String]` |
| `read_zip_file(path, inner)` | `Bytes` |
| `read_zip_text(path, inner, encoding?)` | `String` |
| `read_tar_entries(path)` | `Array[TarEntry]` |
| `list_tar_filenames(path)` | `Array[String]` |
| `read_tar_file(path, inner)` | `Bytes` |
| `read_tar_text(path, inner, encoding?)` | `String` |
| `read_docx_text(path)` | `String` |
| `read_docx_paragraphs(path)` | `Array[String]` |
| `read_excel_sheets(path)` | `Array[ExcelSheet]` |
| `read_excel_sheet_rows(path, i)` | `Array[Array[String]]` |
| `read_excel_sheet_text(path, i)` | `String` |
| `read_excel_first_sheet_rows(path)` | `Array[Array[String]]` |
| `read_excel_first_sheet_text(path)` | `String` |
| `read_pptx_text(path)` | `String` |
| `read_pptx_text_by_slide(path)` | `Array[String]` |
| `read_pdf_text(path)` | `String` |
| `read_pdf_text_by_page(path)` | `Array[String]` |
| `detect_encoding(bytes)` | `Encoding` |
| `parse_encoding(name)` | `Encoding?` |
| `decode(bytes, encoding)` | `String` |
| `decode_auto(bytes)` | `String` |
| `decode_gbk(bytes)` | `String` |
| `decode_big5(bytes)` | `String` |
| `encode(text, encoding, bom?)` | `Bytes` |
| `convert(bytes, from, to)` | `Bytes` |
