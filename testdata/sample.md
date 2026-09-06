# MoonReader 使用指南

这是一个用纯 MoonBit 实现的文件内容读取库。

## 支持的格式

- TXT
- CSV
- JSON
- XML

## 示例代码

```moonbit
let content = @moonreader.read("data.csv")
match content {
  Table(rows) => println(rows.length().to_string())
  _ => ()
}
```

> 提示：全程支持中文文件名，Windows 下 UTF-8 路径感知。

---

详细文档见 README。
