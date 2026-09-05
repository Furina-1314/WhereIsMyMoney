# WhereIsMyMoney 💰

一款 Windows 桌面个人记账程序。

## 技术栈

- **UI**: Qt Quick (QML)，Fluent Design System 风格（Win10 UWP）
- **构建**: CMake + Ninja
- **数据库**: SQLite

## 功能规划

- [x] Phase 1: 仓库与工程骨架
- [ ] Phase 2: 数据层（SQLite schema、数据库管理器、模型）
- [ ] Phase 3: Fluent UI 基础框架与主布局
- [ ] Phase 4: 记账核心（日历选日期、账目增删改查、类别/账户管理）
- [ ] Phase 5: 查询与统计（周/月/自定义区间、图表）
- [ ] Phase 6: 预算（周预算、月预算、超支提示）
- [ ] Phase 7: 打磨与发布

## 功能说明

- 界面左侧为日历，点击某一天即可记录当天账目
- 支持**支出/收入**两种类型：账目名称、详细内容、类别、金额、支出来源/收入流向
- 类别与来源/流向账户均由用户自行创建管理
- 查询与统计：周统计、月统计、自定义起止日期统计
- 预算：编制周预算与月预算，跟踪使用进度

## 构建

依赖：Qt 6（QtQuick）、CMake ≥ 3.19、Ninja（或任意生成器）。

```bash
cmake -B build -DCMAKE_PREFIX_PATH=<Qt 安装路径，如 F:/Qt/6.11.1/mingw_64> -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

## 许可

MIT
