## Summary
- 移除阅读器切章时对可见 H5 的同步导航
- 修复首次阅读后再次点击章节可能无法触发收图的问题
- 上一章/下一章仅使用隐藏 WebView 收图或预取数据
- 保留隐藏 WebView 置顶防 rAF 节流与强制重载优化

## Assets
- Android split APK（armeabi-v7a / arm64-v8a / x86_64）
- unsigned IPA（Actions 构建后自动挂载）
