// Blackbox tests run against the package's public API. Use `@moonreader` to import.
// Prefer high-level behaviors over implementation details.
// Run `moon test` to execute and `moon test --update` to refresh snapshots.

test "detect_format 按扩展名识别格式" {
  assert_eq(@moonreader.detect_format("data/a.csv"), @moonreader.FileFormat::Csv)
  assert_eq(@moonreader.detect_format("data/a.json"), @moonreader.FileFormat::Json)
  assert_eq(@moonreader.detect_format("data/a.jsonl"), @moonreader.FileFormat::Jsonl)
  assert_eq(@moonreader.detect_format("data/a.tar"), @moonreader.FileFormat::Tar)
  assert_eq(@moonreader.detect_format("data/a.txt"), @moonreader.FileFormat::Txt)
}

test "detect_format 不区分大小写且未知扩展名按 TXT" {
  assert_eq(@moonreader.detect_format("a.JSON"), @moonreader.FileFormat::Json)
  assert_eq(@moonreader.detect_format("a.CSV"), @moonreader.FileFormat::Csv)
  assert_eq(@moonreader.detect_format("no_extension"), @moonreader.FileFormat::Txt)
}
