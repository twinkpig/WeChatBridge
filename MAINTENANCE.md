# 维护手册（本地开发 / 同步上游 / 编译安装）

面向在本机改微信流源码并跑起来的人。所有命令都在仓库根执行。

## 1. 仓库与远程

| 远程 | 指向 | 用途 |
| --- | --- | --- |
| `origin` | `github.com/twinkpig/WeChatBridge` | 自己的 fork，有推送权限 |
| `upstream` | `github.com/freestylefly/WeChatBridge` | 原作者仓库，只读（推送会 403） |

推送走 `origin`，拉更新走 `upstream`。

## 2. 同步上游

```bash
git fetch upstream main
git log --oneline main..upstream/main        # 上游有哪些新提交
git rebase upstream/main                     # 把自己的提交挪到最新之上
git push origin main
```

同步前先确认工作区干净（`git status --short` 无输出）、没有 `git stash`。

**历史冲突文件**（上游也在改同一批内容时）：

- `Sources/WeChatBridgeCore/AgentID.swift` — 本地加了 `deepSeek` 分支，上游改枚举结构
- `Resources/Localizations/{en,zh-Hans}.lproj/Localizable.strings` — 双方都在文件末尾追加条目

解冲突时注意：`.strings` 的追加是**并集**，别把整块文案在文件和末尾各留一份（会产生重复 key）。解完用下面这条自查：

```bash
for f in Resources/Localizations/*.lproj/Localizable.strings; do
  total=$(grep -c '^"' "$f")
  uniq=$(grep '^"' "$f" | sed 's/ = .*//' | sort -u | wc -l | tr -d ' ')
  echo "$f: $total / $uniq"
done
```

两数必须相等。

## 3. 编译

```bash
cd <仓库根>
export CLANG_MODULE_CACHE_PATH="$PWD/.clang-cache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.swiftpm-module-cache"
CONFIG=release STORAGE_MODE=shared Scripts/make-app.sh
```

产物：`dist/微信流.app`。

- `STORAGE_MODE`：`shared` 写入 `~/Library/Application Support/WeChatBridge`（本机自用）；`app-group` 用于走 App Group 的分发构建。
- 签名由脚本接管（固定 identity，权限不会因重编译丢失）。**不要手动 `codesign` 重签 appex**，会剥掉 app-sandbox entitlement。

## 4. 安装

```bash
DIST="$PWD/dist/微信流.app"
TARGET="/Applications/微信流.app"

pkill -9 -f "微信流.app/Contents/MacOS/WeChatBridge"   # 必须先退旧版
sleep 2
rm -rf "$TARGET"
cp -R "$DIST" "$TARGET"

LSR=/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister
"$LSR" -f "$TARGET"
for appex in "$TARGET/Contents/PlugIns/"*.appex; do pluginkit -a "$appex"; done

open "$TARGET"
```

`rm -rf` 之前一定核对 `$TARGET` 确实是 `/Applications/微信流.app`。

## 5. 验证装的是新包

```bash
md5 -q dist/微信流.app/Contents/MacOS/WeChatBridge
md5 -q "/Applications/微信流.app/Contents/MacOS/WeChatBridge"   # 两个必须一致

ps -o pid,lstart -p "$(pgrep -f '微信流.app/Contents/MacOS/WeChatBridge' | head -1)"  # 启动时间应晚于编译时间

pluginkit -m -v -p com.apple.share-services | grep -i wechatbridge   # 分享扩展是否注册
```

场景与群绑定存在 `~/Library/Preferences/com.xiangming.wechatbridge.plist`：

```bash
/usr/libexec/PlistBuddy -c "Print :com.xiangming.wechatbridge.scenes.v3" \
  ~/Library/Preferences/com.xiangming.wechatbridge.plist
```

重装 App 不影响这份偏好，但要确认它还在（键名 `...scenes.v3`、`...groupMemory.v1`）。

## 6. 已知的坑

- **改完 App 必须重启才生效。** 只重装不重启，跑的仍是旧进程。用 `pkill -9` 退干净再 `open`。
- **不要用 PyObjC 的 `NSUserDefaults.standardUserDefaults` 写偏好。** 进程没有 bundle id 时它以可执行名（`python3`）为域，写进 `~/Library/Preferences/python3.plist`，App 根本读不到。要写就用 `defaults` / `defaults import` / `PlistBuddy` 针对 `com.xiangming.wechatbridge`。
- **本 App 是 `.accessory`（`LSUIElement`）**，不会成为前台应用：`open` 不会把它激活，AX 只有在它位于最前时才能枚举窗口，`screencapture` 也拿不到画面。验证界面用 `CGWindowListCopyWindowInfo` 查窗口 frame，或写一个编译期小程序针对真实偏好做解码测试。
- **`ScenePickerPanel` 一类的浮层尺寸**由 `FloatingCapsule.measure` 量得。`measure` 会把 hosting view 临时布局在宽 frame 上，量完必须还原它原来的 frame——否则窗口缩到 290pt 后内容仍是 720pt 宽的布局，只会画出左上角一块。
- 外壳进程每次调用都是新 shell，目录不保留：用 `cd <路径> && <命令>` 或显式指定工作目录。
