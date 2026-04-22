# 后台加载URL调试记录

## 问题描述
用户报告后台加载URL（h.js功能）没有成功启用，需要调试定位问题。

## 调试过程

### 1. 初始分析
- 确认问题发生在MainActivity的阅读页面，而非DlActivity
- h.js用于隐藏WebView的后台图片URL获取
- i.js用于主WebView，触发后台加载

### 2. 添加调试日志

#### 2.1 Kotlin端日志
- **JS.kt**: 在`loadComic()`方法中添加`Log.e`日志
- **MainActivity.kt**: 在`loadHiddenUrl()`和WebView初始化处添加`Log.e`日志  
- **WebViewClient.kt**: 在`onPageStarted()`和`onPageFinished()`中添加`Log.e`日志
- **JSHidden.kt**: 添加`log()`方法供JavaScript调用

#### 2.2 JavaScript端日志
- **i.js**: 在`modify()`函数中添加`console.log`
- **h.js**: 将`console.log`改为`GM.log()`以便输出到Android logcat

### 3. 解决日志输出问题

发现release构建中所有日志都被移除了，原因是`proguard-rules.pro`中的规则：
```proguard
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** e(...);
    ...
}
```

**解决**: 注释掉该规则，使日志能在release构建中保留。

### 4. 调试结果

从logcat可以看到：
1. ✅ WebViews初始化成功
2. ✅ 主WebView加载主页，i.js注入成功
3. ✅ 用户点击漫画详情页，隐藏WebView加载详情页，h.js注入成功（8765字符）
4. ✅ 用户点击章节页面，`MyJS.loadComic`被调用
5. ✅ 隐藏WebView加载章节URL，h.js成功注入（8765字符）
6. ❌ **没有看到任何`MyJSH`日志**，说明h.js中的`modify()`函数没有执行或执行出错

### 5. 可能原因
- h.js中的代码可能在执行时出错，导致JavaScript异常
- `modify()`函数可能没有被调用
- 页面结构可能与h.js期望的不符

## 建议后续步骤
1. 检查h.js是否在注入时执行出错（可通过WebView的`onConsoleMessage`捕获）
2. 确认`modify()`函数是否被正确调用
3. 验证页面URL是否符合h.js的预期（包含`/chapter/`）
4. 检查h.js中是否有语法错误或DOM操作错误

## 修改的文件
- `app/src/main/java/top/fumiama/copymangaweb/web/JS.kt`
- `app/src/main/java/top/fumiama/copymangaweb/activity/MainActivity.kt`
- `app/src/main/java/top/fumiama/copymangaweb/web/WebViewClient.kt`
- `app/src/main/java/top/fumiama/copymangaweb/web/JSHidden.kt`
- `app/src/main/assets/i.js`
- `app/src/main/assets/h.js`
- `app/proguard-rules.pro`（注释Log移除规则）

---
调试日期: 2025-04-22
