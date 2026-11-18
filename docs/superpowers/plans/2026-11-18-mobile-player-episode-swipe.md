# Mobile Player Episode Swipe Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 移动端竖屏非全屏播放页去掉「下一集」面板和传输按钮，改为抖音式上下滑切集，并用双播放器预加载相邻一集实现视频跟手过渡。

**Architecture:** 保留现有全屏 Stack 与 Windows/全屏控制层；新增移动端竖屏分支：底部只留进度+全屏，右侧栏保留选集/倍速/弹幕/收藏并新增 Sheet 按钮；长按中间弹播放设置 Sheet，长按左右仍临时 2x；上下滑用两个固定 Video 槽位 + Transform 跟手，当前集播放、预加载集静音暂停，松手吸附后提升预加载播放器。

**Tech Stack:** Flutter、media_kit、Riverpod、现有 `SdkPlaybackRepository` 解析缓存。

**Spec:** 本会话 2026-11-18 已确认的 UI/交互决策（见下方 Global Constraints）。

## Global Constraints

- Windows 桌面端保持现有布局、快捷键、传输按钮与分享入口完全不变。
- 移动端全屏/横屏保持现有布局、传输按钮、长按临时 2x 行为不变。
- 新行为只在 `!Platform.isWindows && !_isWideLayout` 生效。
- 不新增依赖；不绕过 `SdkPlaybackRepository.resolve()` 的 episodeId 缓存。
- 预加载只允许相邻一集，且只在当前集开播后触发；屏外不常驻预取。
- 预加载失败或双解码器压力大时回退封面/首帧，不影响正片播放。
- `flutter analyze` 零 issue；`flutter test` 全绿。

## Review Focus

- 双播放器音频：预加载播放器必须静音且暂停，提升为当前集后才开声音，避免双声道。
- 预加载失败：滑动仍要能用封面过渡，松手后走现有 `_boot` 加载，不能卡死或黑屏。
- 长按区域：中间三分之一弹 Sheet，左右两侧临时 2x；不能误触发播放/暂停。
- 全屏切换：进入全屏释放预加载播放器，退出后恢复预取；全屏行为与现状一致。
- Video 槽位：两个 `Video` 固定槽位，不交给 PageView 回收，避免原生 Surface 重建闪黑。

---

### Task 1: 移动端底部控制条与「下一集」面板

**Files:**
- Modify: `lib/screens/player_screen.dart`（`build` 的竖屏分支、`_PlaybackProgress`、`_ActionRail`）
- Test: `test/ui_layout_check_test.dart`

**Interfaces:**
- `_PlaybackProgress` 新增/复用 `compact`：`compact == true` 时只渲染进度行 + 右侧全屏按钮。
- `_ActionRail` 新增 `required VoidCallback onMore`；compact 模式渲染倍速、选集、弹幕、收藏、更多。

- [ ] **Step 1:** 删除 `build` 中 `if (!isWide) ... _NextEpisodePanel(...)` 整段；删除不再使用的 `_NextEpisodePanel`、`_AutoPlaySwitch` 类。
- [ ] **Step 2:** `_PlaybackProgress` 在 `compact` 时第二行只保留 `Spacer()` + 全屏 `_GlassSquareButton`；非 compact 保持现状。
- [ ] **Step 3:** `_ActionRail.compact` 增加 `onMore` 按钮（`Icons.tune_rounded`，tooltip `播放设置`），移除 compact 下的独立「弹幕设置」项。
- [ ] **Step 4:** 运行 `flutter analyze`，期望 0 issue。
- [ ] **Step 5:** 运行 `flutter test test/ui_layout_check_test.dart`；更新清晰度测试为从「播放设置」Sheet 进入。

### Task 2: 播放设置 Sheet 与长按分区

**Files:**
- Create: `lib/widgets/player_actions_sheet.dart`
- Modify: `lib/screens/player_screen.dart`（`_showPlayerActions`、`onLongPressStart/End/Cancel`）
- Test: `test/ui_layout_check_test.dart`

**Interfaces:**
- `Future<void> showPlayerActionsSheet(BuildContext context, {required bool autoPlay, required ValueChanged<bool> onAutoPlayChanged, required double volume, required bool muted, required ValueChanged<double> onVolumeChanged, required String qualityLabel, required VoidCallback onQuality, required VoidCallback onDanmakuSettings})`
- Sheet 行：清晰度、弹幕设置、自动播放开关、音量滑块。

- [ ] **Step 1:** 新建 `player_actions_sheet.dart`，深色 `AppTokens.immersiveSurface`，底部圆角，SafeArea。
- [ ] **Step 2:** `player_screen.dart` 增加 `_showPlayerActions()`，传入当前 `_autoPlay/_volume/_muted/_currentStream`。
- [ ] **Step 3:** `onLongPressStart`：非 Windows 且非 `isWide` 时，中间 1/3 → `_showPlayerActions()`，左右 1/3 → `_startHoldSpeed()`；`isWide`/Windows 保持现状。
- [ ] **Step 4:** `onLongPressEnd/Cancel` 仅在 `_holdSpeedActive` 时停止临时倍速。
- [ ] **Step 5:** 运行 `flutter analyze` 与 `flutter test test/ui_layout_check_test.dart`。

### Task 3: 双播放器相邻集预加载

**Files:**
- Modify: `lib/screens/player_screen.dart`

**Interfaces:**
- 新增字段：`Player? _preloadPlayer`、`VideoController? _preloadController`、`int? _preloadEpisode`、`PlaybackBundle? _preloadBundle`、`StreamInfo? _preloadStream`、`bool _preloading`。
- `Future<void> _preloadNext()`：仅移动端非全屏、非最后一集；解析下一集，按当前清晰度选流，创建第二个 Player/VideoController，open 后 pause + setVolume(0)。
- `Future<void> _promotePreload()`：落盘当前进度、释放旧播放器、把预加载字段提升为当前、恢复音量/倍速/播放、刷新弹幕、再次 `_preloadNext()`。
- `void _disposePreload()`：释放预加载播放器并清空字段。

- [ ] **Step 1:** 抽出 `_createPlayerAndController()` 复用 `videoOutputConfiguration(defaultVideoOutputMode())` 与日志监听。
- [ ] **Step 2:** 在 `_boot` 成功后调用 `_preloadNext()`；在 `dispose`、进入全屏、切季、切清晰度时调用 `_disposePreload()`。
- [ ] **Step 3:** 实现 `_preloadNext()`，用 `_pickStream(bundle, _currentStream)` 选同档流；任何异常清空预加载字段，不抛到 UI。
- [ ] **Step 4:** 实现 `_promotePreload()`，确保旧播放器 `stop()` 后 `dispose()`，新播放器设置 `_muted ? 0 : _volume * 100`、`_rate`、`play()`。
- [ ] **Step 5:** 运行 `flutter analyze`，期望 0 issue。

### Task 4: 上下滑切集动画

**Files:**
- Modify: `lib/screens/player_screen.dart`

**Interfaces:**
- `_PlayerScreenState with SingleTickerProviderStateMixin`；`late final AnimationController _swipeController`。
- `double _swipeDy = 0`、`int _swipeDirection = 0`（+1 下一集、-1 上一集、0 静止）。
- `_onVerticalDragStart/Update/End`；`_animateSwipe(double target, {VoidCallback? onComplete})`。

- [ ] **Step 1:** 当前 `Video`/弹幕层包一层 `Transform.translate(offset: Offset(0, _swipeDy))`。
- [ ] **Step 2:** 增加相邻集层：`_swipeDirection == 1` 时用 `_preloadController` 的 `Video`，否则用目标集 `PosterArtwork`；offset = `_swipeDirection * screenHeight + _swipeDy`。
- [ ] **Step 3:** `GestureDetector` 增加 `onVerticalDragStart/Update/End`；旧 `onPointerUp` 竖向切集只在 `isWide || Platform.isWindows` 时生效。
- [ ] **Step 4:** 松手阈值 28% 屏高或速度 800px/s；吸附 240ms `easeOutCubic`，回弹 220ms；下一集优先 `_promotePreload()`，无预加载则 `_playNext()`；上一集 `_playPrevious()`。
- [ ] **Step 5:** 顶部/底部控制条保持固定，不随视频位移；滑动中集号不提前改写，吸附后更新。
- [ ] **Step 6:** 运行 `flutter analyze` 与 `flutter test`。

### Task 5: 验证与收尾

- [ ] **Step 1:** `flutter analyze` → 0 issue。
- [ ] **Step 2:** `flutter test` → 全绿。
- [ ] **Step 3:** `flutter test test/ui_layout_check_test.dart` → 全绿，更新受影响的清晰度入口用例。
- [ ] **Step 4:** Android 模拟器手测：上下滑切集、预加载、封面回退、长按分区、Sheet、全屏进出。
- [ ] **Step 5:** Windows 手测：布局、传输按钮、快捷键、分享入口与改动前一致。
- [ ] **Step 6:** 提交：`feat(player): 移动端上下滑切集与播放设置面板`。
