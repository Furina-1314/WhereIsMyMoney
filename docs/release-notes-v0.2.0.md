# WhereIsMyMoney v0.2.0

新增分预算与官方离线安装包。

## 新功能

- **分预算**：周预算 / 月预算内可按类别设置分预算（名称+金额），自动跟踪各类别实际支出，独立进度条与超支提醒，支持合计校验与单条删除
- **离线安装包**：基于 Qt Installer Framework 的 Windows 安装程序（本版本起提供）
  - 向导式安装（欢迎 / 安装目录 / 组件 / 开始菜单）
  - 自动创建开始菜单与桌面快捷方式
  - 附带卸载程序（控制面板可见，卸载干净）

## 安装

下载 `WhereIsMyMoney-Setup-v0.2.0-win64.exe` 双击安装；默认安装到用户目录（无需管理员）。也可用命令行静默安装：

```
WhereIsMyMoney-Setup-v0.2.0-win64.exe install --default-answer --confirm-command -t "C:\安装目录"
```

同样提供免安装版 `WhereIsMyMoney-v0.2.0-win64.zip`（解压即用）。

## 其他

- 类别 / 付款方式管理集中在设置页，删除操作二次确认
- 金额显示统一为逗号千分位 + 两位小数
- dbtest 96 项、应用内端到端自测 57 项全部通过（Debug / Release / 部署包 / 安装后四环境验证）
