# 肩背优先 · SwiftUI 原生 App

完整 iOS / iPadOS 项目，最低 iOS 17，无第三方依赖。全部页面由 SwiftUI 实现，无 WebView。

## 在 Mac 上运行

1. 解压后打开 `ShoulderBack.xcodeproj`。
2. 选择 `ShoulderBack` scheme 和 iPhone / iPad 模拟器，点击 Run。
3. 真机运行：在 Signing & Capabilities 中选择自己的开发团队，并把 `com.example.ShoulderBack` 改为自己的唯一 Bundle ID。

可在 Mac 终端验证编译：

```sh
xcodebuild -project ShoulderBack.xcodeproj -scheme ShoulderBack -sdk iphonesimulator -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

## 已实现

- 今日训练：自动定位星期，展示本周完成度，进入当天动作。
- 一周计划：完整保留源网页七天动作、组数、可选项目、日提示与六条执行原则。
- 逐组完成：原生按钮与触觉反馈，填写每组重量（kg）、次数。
- 周记录：按设备当地时间、周一为起点独立保存，新周不覆盖历史；可查看和编辑历史周。
- 完成度：仅统计必做组 / 项，可选第三组和可选恢复活动不影响 100% 完成。
- 本地持久化：UserDefaults 保存 Codable JSON，退出再打开保留记录。
- 导出：通过原生分享面板导出 JSON 文本。当前版本没有导入功能。
- 休息计时：60 / 90 / 120 秒，可暂停、重置；根据截止时间校正后台经过的时间。关闭计时页面即结束，不发送后台通知。
- 重置本周：原生确认弹窗，历史周记录保留。
- 深色界面、SF Symbols、原生导航与标签栏、iPad 宽度适配。
- 训练动机墙：原网页四张图、标题与说明离线内置；今日页预览、独立动机页。
- 手动添加：从相册选择图片，填写标题与说明；轻点编辑、换图，管理页调整排序或确认删除。
- 动机数据：图片保存到 App 内的私有目录，退出后保留；删除相册原图不会影响已保存的副本。清空动机墙后重启不会恢复默认图片。
- 诗句：今日页与动机页展示中英文标题、两行英文诗句和中文译文。

## 文件

- `App.swift`：入口、配色与卡片样式。
- `Models.swift`：计划模型、周记录、持久化。
- `Views.swift`：今日、计划、动作、历史、执行原则与计时页面。
- `Plan.json`：由源网页提取的训练内容，直接打包进 App。
- `MotivationLibrary.swift`：动机卡片元数据、图片副本与原子保存。
- `MotivationStore.swift`：相册图片处理与界面状态。
- `MotivationViews.swift`：动机墙、添加/编辑/排序页面与诗句。
- `Assets.xcassets`：原网页四张动机图片。
- `tests/MotivationLibraryTests.swift`：Mac 构建前执行的动机数据持久化与失败恢复测试。

## 验证范围与发布准备

在 Windows 上完成了内容映射核对和工程引用检查，未执行 Xcode 编译或 iOS 模拟器视觉验证。请在 Mac 上完成编译和设备验证后使用。

验收建议：逐组切换与重量输入后重启 App；检查七天动作；确认可选组不影响必做完成度；测试计时暂停/后台恢复；导出并核对 JSON；重置本周后检查历史记录。

浏览器 LocalStorage 中既有勾选状态不包含在 HTML 文件里，因此没有迁移浏览器旧记录。v1.1 已加入原网页四张动机图片。App 不联网、不请求健康数据，不含账号、云同步或 HealthKit。相册选择器只提供用户选中的图片；没有整库访问权限。删除 App 会同时删除本地记录和自选图片，覆盖升级请保留原 App。

提交 App Store 前还需配置正式签名、App 图标、商店资料，并验证发布要求。当前交付物是源代码工程，不是 IPA。

## 后续验证

已修复存储错误提示、损坏数据备份和计时暂停。详细结果见 `验证报告.md`。在 Mac 上运行 `bash verify-on-mac.sh` 可执行完整模拟器目标构建，日志保存至 `verification/build.log`。

## v1.1 覆盖更新

训练记录模型、数据键及 Bundle ID 保持原样。通过 GitHub 的 `Build iPhone IPA` 工作流生成新版 IPA，然后使用原来的签名账户、签名工具和实际安装 Bundle ID 覆盖更新。详细操作见 `更新说明.md`。新版完整 Xcode 构建与手机测试仍待执行；Windows 本地检查不是 iOS 编译通过的证明。
