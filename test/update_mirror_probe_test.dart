import 'package:apexduanju/services/update_mirror_probe.dart';
import 'package:apexduanju/services/update_mirrors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UpdateMirrorProbe.rank', () {
    test('成功项按总耗时升序，失败项殿后', () {
      final List<String> order = UpdateMirrorProbe.rank(<MirrorProbeResult>[
        const MirrorProbeResult(
          id: UpdateMirrors.xgetId,
          ok: true,
          ttfb: Duration(milliseconds: 100),
          total: Duration(milliseconds: 1200),
        ),
        const MirrorProbeResult(
          id: UpdateMirrors.ghfastId,
          ok: true,
          ttfb: Duration(milliseconds: 300),
          total: Duration(milliseconds: 500),
        ),
        MirrorProbeResult.failed(UpdateMirrors.ghProxyId),
      ]);
      expect(order, <String>[
        UpdateMirrors.ghfastId,
        UpdateMirrors.xgetId,
        UpdateMirrors.ghProxyId,
      ]);
    });

    test('总耗时相同按首字节延迟排序', () {
      final List<String> order = UpdateMirrorProbe.rank(<MirrorProbeResult>[
        const MirrorProbeResult(
          id: UpdateMirrors.xgetId,
          ok: true,
          ttfb: Duration(milliseconds: 200),
          total: Duration(milliseconds: 500),
        ),
        const MirrorProbeResult(
          id: UpdateMirrors.ghfastId,
          ok: true,
          ttfb: Duration(milliseconds: 100),
          total: Duration(milliseconds: 500),
        ),
      ]);
      expect(order, <String>[UpdateMirrors.ghfastId, UpdateMirrors.xgetId]);
    });

    test('全部失败时保持默认顺序', () {
      final List<String> order = UpdateMirrorProbe.rank(<MirrorProbeResult>[
        MirrorProbeResult.failed(UpdateMirrors.ghProxyId),
        MirrorProbeResult.failed(UpdateMirrors.xgetId),
        MirrorProbeResult.failed(UpdateMirrors.ghfastId),
      ]);
      expect(order, UpdateMirrors.defaultOrder);
    });
  });

  group('UpdateMirrorProbe.preferredOrder', () {
    test('读取测速缓存并补齐缺失镜像', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'update.mirrorOrder': <String>[
          UpdateMirrors.ghProxyId,
          UpdateMirrors.ghfastId,
        ],
      });
      expect(await UpdateMirrorProbe.preferredOrder(), <String>[
        UpdateMirrors.ghProxyId,
        UpdateMirrors.ghfastId,
        UpdateMirrors.xgetId,
      ]);
    });

    test('没有缓存时返回默认顺序', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(
        await UpdateMirrorProbe.preferredOrder(),
        UpdateMirrors.defaultOrder,
      );
    });
  });
}
