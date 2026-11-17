import 'package:openhongguo/openhongguo.dart';

/// 水果端 SDK 客户端单例。
///
/// 首次访问时创建匿名设备（默认机型小米 14），设备档案由 SDK 持久化，
/// 后续请求复用同一台设备。所有仓库共享这一个实例。
class OpenhongguoService {
  OpenhongguoService._();

  static final OpenhongguoService instance = OpenhongguoService._();

  OpenhongguoClient? _client;

  /// 上一次 create/release 的守卫，避免并发首触发生成多个客户端。
  Future<OpenhongguoClient>? _creating;

  /// 拿到可用的客户端；首次调用会注册匿名设备。
  Future<OpenhongguoClient> client() {
    final OpenhongguoClient? existing = _client;
    if (existing != null) {
      return Future<OpenhongguoClient>.value(existing);
    }
    // 0.2.1 起播放请求带真实 argus/ladon 签名，设备不再被整批判空，
    // 换设备次数回到 SDK 默认的 2 次，只作为偶发坏设备的兜底。
    return _creating ??= OpenhongguoClient.create(const ClientOptions(deviceResets: 2)).then(
      (OpenhongguoClient client) {
        _client = client;
        return client;
      },
    ).whenComplete(() => _creating = null);
  }

  /// 丢弃当前匿名设备，下次请求时重新注册。
  Future<void> resetDevice() async {
    final OpenhongguoClient? client = _client;
    if (client == null) {
      return;
    }
    await client.resetDevice();
  }

  /// 释放原生客户端；之后的调用都会失败。
  Future<void> release() async {
    final OpenhongguoClient? client = _client;
    _client = null;
    await client?.release();
  }

  /// 把 SDK 异常翻译成带语义的 App 异常。
  static ApiException translate(Object error) {
    if (error is OpenhongguoException) {
      return ApiException(
        code: error.code.wire,
        message: error.message,
        retryable: error.retryable,
        retryAfterMs: error.retryAfterMs,
      );
    }
    return ApiException(
      code: 'UNKNOWN',
      message: error.toString(),
      retryable: false,
    );
  }
}

/// 统一的业务异常：携带 SDK 错误码、是否可重试与建议等待时长。
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    required this.retryable,
    this.retryAfterMs,
  });

  final String code;
  final String message;
  final bool retryable;
  final int? retryAfterMs;

  /// 面向用户的提示文案。
  String get userMessage {
    switch (code) {
      case 'RATE_LIMITED':
        return '请求太频繁了，稍等一下再试';
      case 'ANONYMOUS_LIMITED':
        // 服务端匿名接口返回空结果：多数是它自己抖动（实测同时出现过 502、
        // 注册接口 transport 失败），不是设备次数用尽，所以文案保持中性。
        return '内容暂时获取失败，请稍后重试';
      case 'DEVICE_REJECTED':
        return '内容暂时获取失败，请稍后重试';
      case 'AUTHENTICATION_REQUIRED':
      case 'CHALLENGE_REQUIRED':
        return '该内容暂不支持匿名访问';
      case 'CONTENT_UNAVAILABLE':
        return '内容已下架或暂不可用';
      case 'TRANSPORT':
        return '网络异常，请检查网络后重试';
      default:
        return '加载失败，请重试';
    }
  }

  @override
  String toString() => 'ApiException($code): $message';
}
