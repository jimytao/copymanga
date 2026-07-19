import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'chapter_data.dart';

/// 漫画目录结构（i.js/h.js setFab 的 JSON 协议）：
/// [{"name": 分组名, "chapters": [{"name": 章节名, "url": PC 章节 URL}]}]
class ComicGroup {
  final String name;
  final List<ComicChapter> chapters;
  ComicGroup(this.name, this.chapters);

  static List<ComicGroup> parseList(String json) {
    final arr = jsonDecode(json) as List;
    return arr
        .map((g) => ComicGroup(
              g['name'] as String? ?? '',
              (g['chapters'] as List? ?? [])
                  .map((c) => ComicChapter(
                      c['name'] as String? ?? '', c['url'] as String? ?? ''))
                  .toList(),
            ))
        .toList();
  }
}

class ComicChapter {
  final String name;
  final String url;
  ComicChapter(this.name, this.url);
}

/// 章节下载与离线管理。目录结构（对应原生版 <漫画名>/<分组>/<章节>.zip）：
/// `<docs>/downloads/<漫画名>/<章节名>/000.webp`，漫画根目录存 `chapters.json`
/// 记录章节顺序（对应原生版 info.bin），供离线上下章导航。
class Downloader {
  static Future<Directory> downloadsRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static String sanitize(String s) =>
      s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  static Future<Directory> comicDir(String comicName) async {
    final root = await downloadsRoot();
    return Directory('${root.path}/${sanitize(comicName)}');
  }

  static Future<Directory> chapterDir(String comicName, String chapterName) async {
    final c = await comicDir(comicName);
    return Directory('${c.path}/${sanitize(chapterName)}');
  }

  /// 保存漫画章节结构（对应原生版 info.bin）
  static Future<void> saveComicMeta(
      String comicName, List<ComicGroup> groups) async {
    final dir = await comicDir(comicName);
    await dir.create(recursive: true);
    final meta = groups
        .map((g) => {
              'name': g.name,
              'chapters':
                  g.chapters.map((c) => {'name': c.name, 'url': c.url}).toList(),
            })
        .toList();
    await File('${dir.path}/chapters.json').writeAsString(jsonEncode(meta));
  }

  static Future<List<ComicGroup>?> loadComicMeta(String comicName) async {
    final dir = await comicDir(comicName);
    final f = File('${dir.path}/chapters.json');
    if (!await f.exists()) return null;
    try {
      return ComicGroup.parseList(await f.readAsString());
    } catch (_) {
      return null;
    }
  }

  static Future<bool> isChapterDownloaded(
      String comicName, String chapterName) async {
    final dir = await chapterDir(comicName, chapterName);
    // 以 .done 为准，避免取消/失败留下的半成品被标成已下载。
    // 旧版无标记的完整下载：再次点下载会跳过已有文件并补写 .done。
    return File('${dir.path}/.done').exists();
  }

  /// 下载图片列表到指定章节目录，[onProgress] 报告 (已完成, 总数)。
  /// 已存在的文件跳过（断点续传）。返回是否全部成功。
  static Future<bool> downloadImages(
    String comicName,
    String chapterName,
    List<String> imgUrls,
    void Function(int done, int total) onProgress, {
    bool Function()? isCancelled,
  }) async {
    final dir = await chapterDir(comicName, chapterName);
    await dir.create(recursive: true);
    final total = imgUrls.length;
    var done = 0;
    var allOk = true;
    const parallel = 4;
    final queue = List.generate(total, (i) => i);
    Future<void> worker() async {
      while (queue.isNotEmpty) {
        if (isCancelled?.call() == true) return;
        final i = queue.removeAt(0);
        final url = wrapResolution(imgUrls[i]);
        final ext = url.contains('.jpg') ? 'jpg' : 'webp';
        final file = File('${dir.path}/${i.toString().padLeft(3, '0')}.$ext');
        if (!await file.exists()) {
          var ok = false;
          for (var attempt = 0; attempt < 3 && !ok; attempt++) {
            try {
              final resp = await http.get(Uri.parse(url), headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
                    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36',
              }).timeout(const Duration(seconds: 30));
              if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
                await file.writeAsBytes(resp.bodyBytes);
                ok = true;
              }
            } catch (_) {}
            if (!ok) await Future.delayed(Duration(milliseconds: 1500 * (attempt + 1)));
          }
          if (!ok) allOk = false;
        }
        done++;
        onProgress(done, total);
      }
    }

    await Future.wait(List.generate(parallel, (_) => worker()));
    // 取消时队列可能未清空，不得当成成功（否则上层会误标“已下载”）
    if (isCancelled?.call() == true) return false;
    if (allOk) {
      await File('${dir.path}/.done').writeAsString('');
    }
    return allOk;
  }

  /// 列出已下载的漫画目录
  static Future<List<Directory>> listComics() async {
    final root = await downloadsRoot();
    final dirs =
        await root.list().where((e) => e is Directory).cast<Directory>().toList();
    dirs.sort((a, b) => a.path.compareTo(b.path));
    return dirs;
  }

  /// 列出某漫画已下载的章节目录，按 chapters.json 的顺序排序（无 meta 按名称）
  static Future<List<Directory>> listChapters(String comicName) async {
    final dir = await comicDir(comicName);
    if (!await dir.exists()) return [];
    final dirs =
        await dir.list().where((e) => e is Directory).cast<Directory>().toList();
    final meta = await loadComicMeta(comicName);
    if (meta != null) {
      final order = <String, int>{};
      var i = 0;
      for (final g in meta) {
        for (final c in g.chapters) {
          order[sanitize(c.name)] = i++;
        }
      }
      dirs.sort((a, b) {
        final an = a.path.split(Platform.pathSeparator).last;
        final bn = b.path.split(Platform.pathSeparator).last;
        return (order[an] ?? 1 << 30).compareTo(order[bn] ?? 1 << 30);
      });
    } else {
      dirs.sort((a, b) => a.path.compareTo(b.path));
    }
    return dirs;
  }

  /// 从本地章节目录构造离线 ChapterData。
  /// [chapterDirs] 为该漫画全部已下载章节（有序），用于离线上下章导航
  /// （next/prev 用 `local://<index>` 伪 URL 表示）。
  static Future<ChapterData?> loadLocal(
    Directory dir, {
    List<Directory>? chapterDirs,
    int initialPage = 0,
  }) async {
    final files = await dir
        .list()
        .where((e) =>
            e is File &&
            !e.path.endsWith('.json') &&
            !e.path.endsWith('.done'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((a, b) => a.path.compareTo(b.path));
    final name = dir.path.split(Platform.pathSeparator).last;
    String? next;
    String? prev;
    if (chapterDirs != null) {
      final idx = chapterDirs.indexWhere((d) => d.path == dir.path);
      if (idx > 0) prev = 'local://${idx - 1}';
      if (idx >= 0 && idx < chapterDirs.length - 1) next = 'local://${idx + 1}';
    }
    return ChapterData(
      title: name,
      uuid: 'local_${dir.path.hashCode}',
      nextChapterUrl: next,
      previousChapterUrl: prev,
      imgUrls: files.map((f) => f.path).toList(),
      isLocal: true,
      initialPage: initialPage,
    );
  }
}
