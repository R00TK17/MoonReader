// ============================================================
// 统一读取入口：按扩展名自动分派
// ============================================================

///|
/// 统一读取结果。调用方按格式 match 得到对应结构。
pub enum Content {
  /// TXT：按行拆分的文本
  Lines(Array[String])
  /// CSV：二维表（行 → 字段）
  Table(Array[Array[String]])
  /// JSON：动态值
  JsonValue(Json)
  /// JSONL：每行一个 JSON 对象
  JsonRows(Array[Json])
  /// XML：根元素（元素树）
  XmlDoc(XmlElement)
  /// Markdown：块结构列表
  MarkdownBlocks(Array[MarkdownBlock])
  /// ZIP：包内条目（文件名 + 内容字节）
  ZipFiles(Array[ZipEntry])
  /// TAR：包内条目（文件名 + 内容字节）
  TarFiles(Array[TarEntry])
  /// DOCX：文档全部文本
  DocxText(String)
  /// XLSX：全部工作表（含多 sheet）
  ExcelSheets(Array[ExcelSheet])
  /// PPTX：每页文本
  PptxSlides(Array[String])
  /// PDF：每页文本
  PdfPages(Array[String])
} derive(Eq, @debug.Debug)

///|
/// 一键读取：根据扩展名自动识别格式并返回对应结果。
pub fn read(path : String) -> Content raise ReaderError {
  match detect_format(path) {
    FileFormat::Txt => Content::Lines(read_txt_by_line(path))
    FileFormat::Csv => Content::Table(read_csv_by_line(path))
    FileFormat::Json => Content::JsonValue(read_json(path))
    FileFormat::Jsonl => Content::JsonRows(read_jsonl_by_line(path))
    FileFormat::Xml => Content::XmlDoc(read_xml(path))
    FileFormat::Markdown => Content::MarkdownBlocks(read_markdown(path))
    FileFormat::Zip => Content::ZipFiles(read_zip_entries(path))
    FileFormat::Tar => Content::TarFiles(read_tar_entries(path))
    FileFormat::Docx => Content::DocxText(read_docx_text(path))
    FileFormat::Xlsx => Content::ExcelSheets(read_excel_sheets(path))
    FileFormat::Pptx => Content::PptxSlides(read_pptx_text_by_slide(path))
    FileFormat::Pdf => Content::PdfPages(read_pdf_text_by_page(path))
  }
}
