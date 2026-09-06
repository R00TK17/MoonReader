// ============================================================
// 文件格式识别
// ============================================================

///|
/// 库当前支持的格式
pub(all) enum FileFormat {
  Txt
  Csv
  Json
  Jsonl
  Xml
  Markdown
  Zip
  Tar
  Docx
  Xlsx
  Pptx
} derive(Eq, @debug.Debug)

///|
/// 根据文件扩展名识别格式（不区分大小写）。
/// 未知扩展名按文本 TXT 处理。
pub fn detect_format(path : String) -> FileFormat {
  let p = path.to_lower()
  if p.has_suffix(".csv".view()) {
    FileFormat::Csv
  } else if p.has_suffix(".jsonl".view()) {
    FileFormat::Jsonl
  } else if p.has_suffix(".json".view()) {
    FileFormat::Json
  } else if p.has_suffix(".xml".view()) {
    FileFormat::Xml
  } else if p.has_suffix(".md".view()) || p.has_suffix(".markdown".view()) {
    FileFormat::Markdown
  } else if p.has_suffix(".zip".view()) {
    FileFormat::Zip
  } else if p.has_suffix(".tar".view()) {
    FileFormat::Tar
  } else if p.has_suffix(".docx".view()) {
    FileFormat::Docx
  } else if p.has_suffix(".xlsx".view()) {
    FileFormat::Xlsx
  } else if p.has_suffix(".pptx".view()) {
    FileFormat::Pptx
  } else {
    FileFormat::Txt
  }
}
