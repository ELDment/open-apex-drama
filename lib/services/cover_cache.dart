import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import '../models/drama.dart';

/// 封面磁盘缓存：按剧集 ID 建键，重启后直接复用本地文件。
///
/// 键里不带 URL：封面地址带 CDN 签名会变，但图还是同一张。
class CoverCache {
  /// 测试用：注入取图函数，完全不触真实缓存。
  @visibleForTesting
  CoverCache.forTesting(this._fetch) : _real = null;

  CoverCache._() : _fetch = null, _real = null;

  static CoverCache instance = CoverCache._();

  /// 有效期 7 天：封面基本不变，过期后重新下载，失败则沿用旧图。
  static const Duration maxAge = Duration(days: 7);

  /// 最多缓存的张数，超出后淘汰最久未使用的（按张数而非字节）。
  static const int maxObjects = 1500;

  static const String _cacheKey = 'apexDramaCovers';

  /// 非空时完全接管；为 null 时走真实的磁盘缓存。
  final Stream<File> Function(String url, String key)? _fetch;

  BaseCacheManager? _real;

  /// 取出 [drama] 的封面文件：先吐出已有的旧图（若有且未过期则只有这一份），
  /// 过期或没有缓存时再下载，下载成功后吐出新图并写入缓存。
  ///
  /// 订阅方自行吞掉错误：下载失败不影响已经显示的旧图。
  Stream<File> load(Drama drama) {
    final String key = 'cover:${drama.id}';
    final Stream<File> Function(String url, String key)? fetch = _fetch;
    if (fetch != null) {
      return fetch(drama.coverUrl, key);
    }
    // 管理器返回的是 package:file 的 File，按路径转成 dart:io 的才能交给 Image.file。
    return (_real ??= _createManager())
        .getFileStream(drama.coverUrl, key: key)
        .where((FileResponse event) => event is FileInfo)
        .map((FileResponse info) => File((info as FileInfo).file.path));
  }

  static BaseCacheManager _createManager() {
    return CacheManager(
      Config(
        _cacheKey,
        stalePeriod: maxAge,
        maxNrOfCacheObjects: maxObjects,
        fileService: _FixedAgeFileService(HttpFileService()),
      ),
    );
  }
}

/// 把有效期固定为 [CoverCache.maxAge]，不听 CDN 的 Cache-Control：
/// 对端回 `no-cache` 会导致每次都重下，回超长 max-age 则永远不更新。
class _FixedAgeFileService implements FileService {
  _FixedAgeFileService(this._inner);

  final FileService _inner;

  @override
  int concurrentFetches = 10;

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _FixedAgeResponse(await _inner.get(url, headers: headers));
  }
}

class _FixedAgeResponse implements FileServiceResponse {
  _FixedAgeResponse(this._inner)
    : validTill = DateTime.now().add(CoverCache.maxAge);

  final FileServiceResponse _inner;

  @override
  final DateTime validTill;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  int get statusCode => _inner.statusCode;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension => _inner.fileExtension;
}
