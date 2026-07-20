## Summary
- 退出阅读器后恢复表页定时器，修复 iOS 无法再次点章进阅读器
- 退出时把 preUrl 标成当前地址，避免仍停在章节页时阅读器自动弹回
- 取消阅读器内对表 H5 的 clickClass 同步，避免安卓关阅读器像跳回首页
- 详情/章节页网页返回优先 history.back，失败回落上次浏览位
- WebView 透明底减轻启动白闪

## Assets
- Android split APK（armeabi-v7a / arm64-v8a / x86_64）
- unsigned IPA（Actions 构建后自动挂载）
