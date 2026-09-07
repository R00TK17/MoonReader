# MoonReader

A pure-MoonBit file content reading library. It reads **12 formats** — TXT / CSV / JSON / JSONL / XML / Markdown / ZIP / TAR / DOCX / XLSX / PPTX / PDF — with full **Chinese-filename support** (UTF-8 path aware on Windows) and built-in **encoding auto-detection** (UTF-8 / UTF-16 / UTF-32 / GBK / Big5 / Latin-1).

```text
Package:   R00TK17/moonreader   (version 0.1.0)
Targets:   native · llvm · wasm-gc
License:   Apache-2.0
```

---

## Using this repository

MoonReader is both a library and a runnable project. The `cmd/main` package is a CLI demo that exercises every format against the fixtures in `testdata/`.

### Prerequisites

- [MoonBit](https://www.moonbitlang.com/) toolchain (the `moon` CLI). This project is developed against `0.1.20260827`.

### Build

```bash
moon build                     # native target
moon build --target wasm-gc    # browser / IDE preview target
```

### Test

```bash
moon test
```

### Run the CLI demo

```bash
moon run cmd/main -- testdata/sample.csv              # CSV
moon run cmd/main -- testdata/中文.txt                 # TXT with Chinese filename
moon run cmd/main -- testdata/sample.json             # JSON
moon run cmd/main -- testdata/sample.jsonl            # JSONL
moon run cmd/main -- testdata/sample.xml              # XML
moon run cmd/main -- testdata/sample.md               # Markdown
moon run cmd/main -- testdata/sample.zip              # list & dump ZIP entries
moon run cmd/main -- testdata/sample.zip sample.txt   # read one inner file
moon run cmd/main -- testdata/sample.tar              # list & dump TAR entries
moon run cmd/main -- testdata/sample.tar alpha.txt    # read one inner file
moon run cmd/main -- testdata/sample.docx             # Word
moon run cmd/main -- testdata/sample.xlsx             # Excel
moon run cmd/main -- testdata/sample.pptx             # PowerPoint
moon run cmd/main -- testdata/sample.pdf              # PDF

# encoding conversion: convert <file> <target> [source] [output]
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8            # auto-detect source, overwrite
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk        # explicit source
moon run cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk out.txt # save to new file
```

### Run under wasm-gc

The same CLI compiles to `wasm-gc` (file I/O delegated to `moonbitlang/x/fs`; Chinese filenames and encoding detection still work):

```bash
moon run --target wasm-gc cmd/main -- testdata/sample.csv
moon run --target wasm-gc cmd/main -- testdata/中文.txt
moon run --target wasm-gc cmd/main -- convert testdata/encoding_gbk.txt utf-8 gbk out.txt
```

### Project layout

```text
cmd/main/             CLI demo (executable)
*.mbt                 the library — one file per format
fs_utf8.c             native file I/O C stub (UTF-8 path aware)
fs_utf8_native.mbt    file I/O for native / llvm
fs_utf8_wasm.mbt      file I/O for wasm-gc (delegates to @fs)
testdata/             fixtures: 12 formats + Chinese filenames + encodings
moonreader_test.mbt   blackbox tests
moon.pkg              package config (imports + per-target file selection)
moon.mod              package metadata
```

---

## Dependencies

The library is written in MoonBit. Archive decompression delegates to third-party packages (both pure MoonBit, no C FFI):

| Package | Version | Used for |
|---|---|---|
| `hustcer/fzip` | `0.8.6` | ZIP / DEFLATE decompression — backs **ZIP**, and **DOCX / XLSX / PPTX / PDF** (OOXML archives and PDF `FlateDecode` streams) |
| `moonbitlang/x` | `0.5.1` | `@fs` file I/O on the **wasm-gc** target |

Everything else — TXT / CSV / JSON / JSONL / XML / Markdown / TAR, encoding detection & conversion, and the structural parsing of PDF / XLSX / PPTX / DOCX — is implemented directly in this repository.

`moonbitlang/core` (json, debug, base64, utf8, utf16, ref) is the standard library and is always available.

---

## Installation

Add the package to your project:

```bash
moon add R00TK17/moonreader
```

Then import it in your `moon.pkg`:

```moonbit
import {
  "R00TK17/moonreader",
}
```

All APIs live in the flat `@moonreader` namespace — a single import is all you need.

---

## Quick start

Call `read(path)` to detect the format from the file extension and get a typed result:

```moonbit
let content = @moonreader.read("data/sample.csv")

match content {
  @moonreader.Content::Table(rows) => {
    // CSV → 2D array (row → fields)
    for row in rows {
      println(row.join(" | "))
    }
  }
  @moonreader.Content::Lines(lines) => println(lines.join("\n"))
  @moonreader.Content::JsonValue(j) => println(j.stringify(indent=2))
  @moonreader.Content::XmlDoc(root) => println(root.to_string())
  @moonreader.Content::PdfPages(pages) => println(pages.join("\n---\n"))
  _ => println("other format")
}
```

> `read` returns a `Content` enum. Match on it to get the concrete structure for each format. Constructors can also be written unqualified inside a `match` (`Table(rows)`, `Lines(lines)`, …) since the scrutinee type is known.

---

## Unified entry

| Function | Description |
|---|---|
| `detect_format(path : String) -> FileFormat` | Detect format by extension (`.txt` `.csv` `.json` `.jsonl` `.xml` `.md` `.zip` `.tar` `.docx` `.xlsx` `.pptx` `.pdf`, case-insensitive; unknown → `Txt`) |
| `read(path : String) -> Content raise ReaderError` | Auto-dispatch and return the unified result |

### `Content` variants

| Variant | Format | Payload |
|---|---|---|
| `Lines` | TXT | `Array[String]` (by line) |
| `Table` | CSV | `Array[Array[String]]` (row → fields) |
| `JsonValue` | JSON | `Json` (dynamic value) |
| `JsonRows` | JSONL | `Array[Json]` (one object per line) |
| `XmlDoc` | XML | `XmlElement` (root element tree) |
| `MarkdownBlocks` | Markdown | `Array[MarkdownBlock]` |
| `ZipFiles` | ZIP | `Array[ZipEntry]` (name + content bytes) |
| `TarFiles` | TAR | `Array[TarEntry]` (name + content bytes) |
| `DocxText` | DOCX | `String` (full document text) |
| `ExcelSheets` | XLSX | `Array[ExcelSheet]` (all sheets) |
| `PptxSlides` | PPTX | `Array[String]` (per-slide text) |
| `PdfPages` | PDF | `Array[String]` (per-page text) |

### `FileFormat` variants

`Txt · Csv · Json · Jsonl · Xml · Markdown · Zip · Tar · Docx · Xlsx · Pptx · Pdf`

```moonbit
if @moonreader.detect_format("report.PDF") == @moonreader.FileFormat::Pdf {
  // ...
}
```

---

## Error handling

Every function that can fail raises the unified error type `ReaderError`:

```moonbit
try {
  let j = @moonreader.read_json("data.json")
} catch {
  Io(msg) => println("I/O error: \{msg}")
  Parse(msg) => println("parse error: \{msg}")
}
```

- `ReaderError::Io(String)` — file could not be opened / read / written.
- `ReaderError::Parse(String)` — content could not be parsed.

---

## Text (TXT) and raw file I/O

```moonbit
@moonreader.read_txt("a.txt")                  // String  (encoding auto-detected)
@moonreader.read_txt_by_line("a.txt")          // Array[String]
@moonreader.read_txt_by_byte("a.txt")          // Bytes (raw)
@moonreader.read_txt_by_block("a.txt", 1024)   // Array[String], 1024 chars per block

// optional explicit encoding
@moonreader.read_txt("a.txt", encoding=Some(@moonreader.Encoding::Gbk))
```

Generic byte-level file I/O (any file, Chinese-filename friendly):

```moonbit
let raw : Bytes = @moonreader.read_file_to_bytes("data/blob.bin")
@moonreader.write_file_to_bytes("data/out.bin", raw)   // overwrite
```

---

## CSV

```moonbit
let rows = @moonreader.read_csv_by_line("data.csv")        // Array[Array[String]]
let cols = @moonreader.read_csv_by_column("data.csv")      // transposed (column → values)
let blks = @moonreader.read_csv_by_block("data.csv", 100)  // Array[Array[Array[String]]]
```

---

## JSON / JSONL

`read_json` returns `Json` (from `moonbitlang/core/json`), so you can use `.stringify()`, `[field]`, etc. To call those methods, also import `moonbitlang/core/json` in your `moon.pkg`.

```moonbit
let j = @moonreader.read_json("data.json")       // Json
println(j.stringify(indent=2))

let js = @moonreader.read_jsonl_by_line("data.jsonl")   // Array[Json]
let blocks = @moonreader.read_json_by_block("data.json", 50) // Array[Array[Json]]
```

---

## XML

Parse a file, or a string directly. Navigate the tree with the `XmlElement` methods:

```moonbit
let root = @moonreader.read_xml("data.xml")       // XmlElement
// or: @moonreader.parse_xml("<r><a>hi</a></r>")

root.name                    // String
root.attrs                   // Array[(String, String)]
root.text()                  // String: all descendant text
root.attr("id")              // String?
root.to_string()             // String: indented XML

root.child_elements()        // Array[XmlElement]: direct element children
root.find("item")            // XmlElement?: first descendant named "item"
root.find_all("item")        // Array[XmlElement]: every descendant named "item"
```

---

## Markdown

```moonbit
let blocks = @moonreader.read_markdown("README.md")  // Array[MarkdownBlock]
// or: @moonreader.parse_markdown("# Title\n\n- one\n- two\n")

for b in blocks {
  println(b.to_string())
}
```

`MarkdownBlock` variants: `Heading(Int, String) · Paragraph(String) · CodeBlock(String, String) · Quote(String) · ListItem(String) · HorizontalRule`.

---

## ZIP

ZIP decompression is provided by the pure-MoonBit `hustcer/fzip` package.

```moonbit
let entries = @moonreader.read_zip_entries("a.zip")   // Array[ZipEntry] (name + content)
@moonreader.list_zip_filenames("a.zip")               // Array[String]
@moonreader.read_zip_file("a.zip", "inner.txt")       // Bytes (raw)
@moonreader.read_zip_text("a.zip", "inner.txt")       // String (encoding auto-detected)

for e in entries {
  println("\{e.name} → \{e.text()}")   // e.text() decodes with auto detection
}
```

`ZipEntry` fields: `name : String`, `content : Bytes`.

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

`TarEntry` fields: `name : String`, `content : Bytes`.

---

## Office (OOXML)

```moonbit
// DOCX
@moonreader.read_docx_text("a.docx")            // String (all paragraphs)
@moonreader.read_docx_paragraphs("a.docx")      // Array[String]

// XLSX
@moonreader.read_excel_sheets("a.xlsx")         // Array[ExcelSheet] (name + rows)
@moonreader.read_excel_sheet_rows("a.xlsx", 1)  // Array[Array[String]] — sheet index 1
@moonreader.read_excel_sheet_text("a.xlsx", 1)  // String — sheet index 1
@moonreader.read_excel_first_sheet_rows("a.xlsx")  // first sheet → 2D array
@moonreader.read_excel_first_sheet_text("a.xlsx")  // first sheet → String

// PPTX
@moonreader.read_pptx_text("a.pptx")            // String (all slides)
@moonreader.read_pptx_text_by_slide("a.pptx")   // Array[String] (per slide)
```

`ExcelSheet` fields: `name : String`, `rows : Array[Array[String]]`.

---

## PDF

```moonbit
@moonreader.read_pdf_text("a.pdf")             // String (all pages)
@moonreader.read_pdf_text_by_page("a.pdf")     // Array[String] (per page)
```

---

## Encoding detection & conversion

Text formats (TXT / CSV / JSON / JSONL / XML / Markdown, and inner files in ZIP / TAR) **auto-detect encoding by default**. You can also pass `encoding=` explicitly.

| Function | Description |
|---|---|
| `detect_encoding(bytes) -> Encoding` | Probe a byte stream's encoding |
| `parse_encoding(name) -> Encoding?` | Name → `Encoding` (aliases: `gbk`/`gb2312`/`cp936`/`gb18030`, `big5`/`cp950`, `utf-8`, `utf-16`/`utf-16le`/`utf-16be`, `utf-32`, `latin1`) |
| `decode(bytes, encoding) -> String` | Decode with a given encoding |
| `decode_auto(bytes) -> String` | Auto-detect and decode |
| `encode(text, encoding, bom?=false) -> Bytes` | Encode to a given encoding |
| `convert(bytes, from, to) -> Bytes` | Convert between two encodings |

`Encoding` variants: `Utf8 · Utf16Le · Utf16Be · Utf32Le · Utf32Be · Gbk · Big5 · Latin1`.

```moonbit
// GBK legacy data → UTF-8 bytes → write back (Chinese filename ok)
let gbk  = @moonreader.read_file_to_bytes("data/老数据.csv")
let utf8 = @moonreader.convert(gbk, @moonreader.Encoding::Gbk, @moonreader.Encoding::Utf8)
@moonreader.write_file_to_bytes("data/新数据.csv", utf8)

// auto-detect vs explicit
@moonreader.read_txt("data/老数据.txt")                                     // GBK detected
@moonreader.read_txt("data/繁体.txt", encoding=Some(@moonreader.Encoding::Big5))
```

> **Note:** GBK vs Big5 are byte-level ambiguous, so auto-detection defaults to GBK for double-byte sequences. Use `encoding=Some(Encoding::Big5)` for traditional Chinese.

---

## Chinese filenames

On Windows the native backend opens files via `_wfopen` after UTF-8 path conversion, so both the outer path and names inside zip/tar archives may be Chinese. On `wasm-gc` the path is handed to the host as a string, which is UTF-8 native.

---

## Targets

| Target | File I/O backend |
|---|---|
| `native` / `llvm` | C stub (`fs_utf8.c`) via `_wfopen` |
| `wasm-gc` | delegates to `moonbitlang/x/fs` |

The public API is identical across targets. `js` and `wasm` (WASI) are not currently wired up.

---

## Complete API index

| Function | Returns |
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
