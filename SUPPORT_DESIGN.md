# SUPPORT_DESIGN — macOS 12–26 全版本支持：可行性分析与重构方案

> 状态：**已决策，实施中**
> 决策记录（2026-08-23）：
> - 菜单栏入口采用 **方案 A：双轨条件编译**（13+ 保持 MenuBarExtra，12 使用 NSStatusItem+NSPopover）
> - 最低支持目标：**macOS 12.0**

---

## 一、结论

**可行，成本中等偏低。** 核心识别引擎、动作执行器、持久化层全部基于 Foundation/AppKit 老 API，
零改动即可兼容 macOS 12。需要改动的只有 UI 壳层的 8 个阻塞点。

⚠️ 环境约束：当前开发机为 **macOS 12.7 + Xcode 14.2**，无法编译本项目（Xcode 26 需要 macOS 15+）。
本项目须在配备 Xcode 26 的机器（或 CI）上构建验证；本机恰好充当 **macOS 12 真实测试机**。

## 二、天然兼容部分（零改动）

| 模块 | 依赖 | 结论 |
|---|---|---|
| 识别引擎 (`GestureMatcher`/`GestureNormalizer`) | 纯 Foundation | ✅ |
| 触摸采集 (`TouchCaptureManager`) | MultitouchSupport 私有 C API | ✅ 10.x 时代 API，全版本稳定 |
| 动作执行 (`Actions/*`) | CGEvent tap、AXUIElement、Carbon HIToolbox、NSWorkspace | ✅ |
| 覆盖层 (`GestureOverlayWindow`) | borderless NSWindow + level + collectionBehavior | ✅ |
| 持久化 (`GestureStore`) | Foundation JSON | ✅ |
| `@Observable` ×4 类 | Observation 框架 | ❌ **已被 CI 证伪**：`Observable()` 宏标注为 macOS 14+，无回溯部署。已迁移至 `ObservableObject/@Published`（见实施记录 v2） |
| Swift 并发 + `SWIFT_DEFAULT_ACTOR_ISOLATION=MainActor` | Xcode 26 编译器选项 | ✅ 与目标系统版本无关 |
| 图标资产 | 传统 AppIcon.appiconset（非 Icon Composer） | ✅ |
| SF Symbols 53 个中的 49 个 | 实测验证（name_availability.plist + AppKit 运行时，macOS 12.7 本机） | ✅ |

## 三、8 个阻塞点

| # | 位置 | API | 最低要求 | 改法 |
|---|---|---|---|---|
| 1 | trackpad_controlApp.swift:8,11 | `MenuBarExtra` + `.menuBarExtraStyle(.menu)` | 13.0 | 方案 A 双轨（见第五节） |
| 2 | SettingsRootView.swift:7 | `NavigationSplitView` | 13.0 | 12 用自定义 HStack 侧栏分支 |
| 3 | SettingsRootView.swift:26 | `.toolbar(removing: .sidebarToggle)` | 13.0 | 包 `#available(macOS 13.0, *)` |
| 4 | GesturesView.swift:142 | `ContentUnavailableView` | 14.0 | 自定义替身 View（Compatibility.swift） |
| 5 | TriggerEditorView:35、AdvancedView:30/37/51/58、TrackpadRecorderView:24/36 | `onChange` 新签名 ×7 | 14.0 | 统一改走兼容包装（内部用旧式 `onChange(of:perform:)`），全版本可编译 |
| 6 | WindowManager:421/473/539/549 | `activate()` 无参形式 ×4 | 14.0 | 改回老形式（`activate(ignoringOtherApps:)` / `activate(options:)`） |
| 7 | SF Symbol 字符串 4 组共 7 行 | 见下表 | 12 实测缺失 | 直接改名，新旧系统均安全 |
| 8 | pbxproj:326/384/465/486 | `MACOSX_DEPLOYMENT_TARGET = 26.4` | — | 改为 `12.0`（LSMinimumSystemVersion 自动生成） |

### SF Symbol 替换表

已在本机 macOS 12.7 实测验证替换名可用；旧名在新系统作为 deprecated 别名继续解析，双向安全。
（命名沿革佐证：Geoff Hackworth 的 SF Symbols 改名系列研究）

| 现用符号 | 替换为 | 出现位置 |
|---|---|---|
| `dial.low` | `dial.min` | GestureDefinition.swift:17、GestureEditorSheet.swift:285 |
| `touch.radiowaves.left` | `radiowaves.left` | GestureEditorSheet.swift:250 |
| `point.topleft.down.to.point.bottomright.curvepath` | `point.topleft.down.curvedto.point.bottomright.up` | TrackpadRecorderView.swift:66 |
| `hand.raised.fingers.spread` | `hand.raised.fill` | GesturesView.swift:114、GestureEditorSheet.swift:679、RecognitionView.swift:157 |

## 四、方案分叉决策点：菜单栏入口（已选 A）

| 方案 | 做法 | 结论 |
|---|---|---|
| **A. 双轨条件编译 ✅ 已选** | 13+ 继续 `MenuBarExtra`；12 用 `NSStatusItem`+`NSPopover` 承载现有 `MenuBarContentView`（SwiftUI 内容复用，通过 `withObservationTracking` 手动订阅图标状态变化） | 新系统 UX 与现状完全一致；代价是维护 ~100 行遗留路径代码 |
| B. 统一 NSStatusItem+NSPopover | 全版本替换 | 代码最简，但 26 上原生菜单观感改变 —— 未采纳 |
| C. 统一原生 NSMenu 重写 | SwiftUI 内容翻译成菜单项 | 最接近 `.menu` 样式但丢失自定义 UI，工作量大 —— 未采纳 |

## 五、风险与注意事项

1. **编译验证必须在 Xcode 26 环境**（另一台机器或 GitHub Actions `macos-15` runner）。Xcode 26 支持 macOS 12 部署目标。
2. `@Observable` 回溯部署是官方特性，仍需在 12.7 真机重点回归：录制实时路径刷新、telemetrics 是否正常驱动视图。
3. 各版本行为差异需 QA：全屏 Space 窗口枚举、Stage Manager（13+ 才有）、AX 权限弹窗文案、事件 tap 被系统禁用的恢复逻辑
   （TouchCaptureManager.swift:362 已有防护注释与实现）。
4. 兼容层使用旧式 `onChange(of:perform:)` 与 `activate(ignoringOtherApps:)`，在 Xcode 26 构建时会产生弃用警告——这是预期行为，
   将来若提升最低版本到 14 只需删除 Compatibility.swift 并还原调用点。
5. README 的 "Requires macOS 26 and Xcode 26+" 及下载说明需同步更新。
6. 项目使用 `fileSystemSynchronizedGroups`（objectVersion 77），新增源文件放入目录即自动纳入 target，无需手工登记 pbxproj。

## 六、实施计划

```
Phase 0  决策         菜单栏方案 A / 最低 12.0                        ✅ 完成
Phase 1  机械改动     pbxproj 目标版本、onChange ×7、                 ✅ 完成
                      activate() ×4、SF Symbol ×4 组
Phase 2  设置窗口     NavigationSplitView 分支、sidebarToggle、       ✅ 完成
                      ContentUnavailableView 替身
Phase 3  菜单栏入口   双轨：MenuBarExtra(13+) / NSStatusItem(12)      ✅ 完成
Phase 4  回归验证     12.7（本机真机）+ 13/14/15 + 26 测试矩阵：      🔄 进行中
                      （2026-08-23：CI 构建✅ 双架构校验✅、
                       Intel Mac 12.7 安装并启动运行✅；
                       功能级回归见第九节清单，逐项执行中）
Phase 5  文档         README / docs 更新                              ✅ 完成（README 已更新）
```

### 实施记录 v2（CI 首次构建失败后的修复，2026-08-23）

**发现 1 — @Observable 不可回溯部署**：CI 报错 `'Observable()' is only available in macOS 14.0 or newer`。
原报告中"Observation 框架官方回溯部署至 10.15"的判断错误。修复：
- `AppState` / `RecognitionSettings` / `AppearanceSettings` / `GestureStore` 全部迁移为
  `ObservableObject + @Published`（Combine，macOS 10.15+ 全兼容）
- AppState 通过 `objectWillChange` 转发 GestureStore 的变化，保持视图刷新链路不变
- 嵌套对象语义差异处理：读取/绑定嵌套设置的视图各自持有专属 `@ObservedObject`
  （RecognitionView→rs、AppearanceView→aps、MenuBarContentView→rs、ModernApp→rs）
- LegacyMenuBarController 改用 Combine 订阅替代 Observation 跟踪循环

**发现 2 — CI runner 为 Apple Silicon**：用户机器是 Intel Mac，必须保证产物含 x86_64。
workflow 已强制 `ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO` 并用 `lipo -archs` 校验双架构，
缺失任一架构即失败；另增加 build.log 失败时自动上传，便于无 gh CLI 时排查。

**发布流程（2026-08-23 新增）**：`.github/workflows/release.yml` 由 tag 推送触发
（`git tag vX.Y.Z && git push origin vX.Y.Z`），构建通用二进制并自动创建 GitHub Release，
附件 `trackpad_control.zip` 与 README 下载链接约定一致。

### 实施记录 v1（2026-08-23）

**新增文件**
- `trackpad_control/Support/Compatibility.swift` — `tcOnChange` 兼容包装（内部走旧式
  `onChange(of:perform:)`，全版本可编译，仅新 SDK 有集中弃用警告）、`tcRemoveSidebarToggle`
  条件修饰符、`UnavailableStateView`（14+ 用原生 ContentUnavailableView，12/13 用近似布局替身）。
- `trackpad_control/Support/LegacyMenuBarController.swift` — macOS 12 的菜单栏入口：
  NSStatusItem + **原生 NSMenu**（Tracking 复选项 / Settings… / Quit，键位与 MenuBarExtra 一致）。
  实施时从方案 A 原文的 NSPopover 细化为 NSMenu：现有 `MenuBarContentView` 仅含菜单级控件，
  原生菜单与 13+ `.menu` 样式观感完全一致且更稳定；图标状态通过 `withObservationTracking`
  手动订阅 `@Observable`（Observation 框架官方回溯部署至 10.15）。

**修改文件**
- `trackpad_control.xcodeproj/project.pbxproj` — `MACOSX_DEPLOYMENT_TARGET = 12.0`（4 处）
- `trackpad_control/trackpad_controlApp.swift` — 入口重构为三段：`@main AppEntry` 按
  `#available(macOS 13.0, *)` 分发到 `ModernApp`（原 MenuBarExtra 场景，行为不变）或
  `LegacyApp`（NSApplicationDelegateAdaptor 在 didFinishLaunching 安装状态项；
  Settings{EmptyView()} 作为惰性锚点场景）。公共启动逻辑抽为 `AppStartup.perform()`。
- `Actions/WindowManager.swift` — 4 处无参 `activate()` → `activate(options: .activateIgnoringOtherApps)`
- `Views/Gestures/TriggerEditorView.swift`、`Views/Settings/AdvancedView.swift`、
  `Views/Gestures/TrackpadRecorderView.swift` — onChange 新签名 ×7 → `.tcOnChange`
- `Views/Settings/SettingsRootView.swift` — NavigationSplitView 双轨（12 用自定义侧栏 HStack）
- `Views/Settings/GesturesView.swift` — emptyState 改用 `UnavailableStateView`
- SF Symbol ×4 组 7 行（见第三节替换表）：GestureDefinition / GestureEditorSheet ×3 /
  TrackpadRecorderView / GesturesView / RecognitionView

**本地验证情况**
- `plutil -lint` pbxproj 通过；全部改动文件经语法解析无错误（本机 Xcode 14.2 对预存的
  Swift 5.9 `switch` 表达式与 `nonisolated(unsafe)` 报解析错属解析器版本限制，与本次改动无关，
  Xcode 26 可正常编译）。
- ⚠️ 类型级验证（可用性、宏展开、隔离检查）必须在 Xcode 26 环境执行首次构建确认。

## 八、兼容代码标识约定（TC_COMPAT）

所有为支持 macOS 26 以下系统而做的偏离均以 `TC_COMPAT(...)` 注释标识，可全局搜索。
共 36 处，分布于 12 个文件：

| 标签 | 含义 | 覆盖位置 |
|---|---|---|
| `TC_COMPAT(<13)` | 需要 Ventura 以下运行时分支（菜单栏入口、设置侧栏） | trackpad_controlApp.swift ×4、SettingsRootView.swift ×4、LegacyMenuBarController.swift、Compatibility.swift |
| `TC_COMPAT(<14)` | 现代 API 需 Sonoma，替换为旧形式（双参 onChange、无参 activate()、toolbar(removing:)、ContentUnavailableView） | Compatibility.swift、WindowManager.swift ×4、onChange ×7、UnavailableStateView 及其调用点 |
| `TC_COMPAT(macOS 12)` | SF Symbol 改名（新名在 Monterey 符号集缺失，替换名全版本可用） | 7 行符号字符串 |

集中实现位于 `trackpad_control/Support/Compatibility.swift` 文件头。将来提升最低版本时，
按标签删除对应代码并还原直调即可。

## 九、验收清单（Phase 4 用）

> 状态标记：✅ 通过 · ⬜ 待测 · ➖ 无设备暂缓
> 最后更新：2026-08-23

### A. 构建 / 打包（CI）

- ✅ Xcode 26 Release 构建通过（run 32645218096 及后续 tag 构建）
- ✅ 部署目标校验：二进制 `minos = 12.0`，`LSMinimumSystemVersion = 12.0`
- ✅ 双架构校验：`lipo -archs` 含 x86_64 + arm64（单一通用二进制，非两份产物）
- ✅ 本机实测：Intel Mac (macOS 12.7) 安装 `/Applications` 并启动运行正常

### B. macOS 12.7 真机功能回归（本机执行）

- ✅ 状态栏图标出现、菜单弹出（随安装启动确认）；Tracking 开关切换时图标的动态变化待复测
- ⬜ 录制链路：新建输入 → 录制手势，实时路径渲染流畅（验证 @Published 迁移后
  `recordingUpdateCounter` 驱动的刷新）、完成后可保存
- ⬜ 四类动作实际触发：键盘快捷键 / 启动 App / 窗口管理 / 连续操作
- ⬜ 覆盖层轨迹绘制正常；诊断自测通过：
  `TC_OVERLAY_SELF_TEST=1 open -a "Trackpad Control"`
- ⬜ 设置窗口：四个标签页切换正常、空列表占位视图观感可接受
  （`UnavailableStateView` 的 12/13 替身布局）
- ⬜ 导入/导出 JSON 往返一致（含 51 个预录手势的 starter-gestures.json）
- ⬜ 开机启动开关保存并生效
- ⬜ 内存观察：挂机 ≥30 分钟无异常增长（参考 docs/macos-low-memory-playbook.md）

### C. 其他系统版本矩阵

- ⬜ macOS 13/14/15：MenuBarExtra 路径行为与重构前一致；重点验证菜单栏图标随
  Tracking 切换（ModernApp 属性包装器改动点）——➖ 如无对应设备可暂缓
- ⬜ macOS 26：无视觉/功能回归 —— ➖ 需要 Tahoe 设备时再测

### D. 收尾

- ✅ release.yml 全流程演练（tag 触发 → 构建校验 → 发布附件 trackpad_control.zip）
- ⬜ 清理预存 Swift 6 模式警告（WindowManager.Direction 隔离警告等，不阻塞）
