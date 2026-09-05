// 数据层自测：覆盖 schema、类别/账户/账目 CRUD、约束校验、统计聚合、预算 upsert。
// 全部用临时目录数据库，测试结束自动清理。
#include <QCoreApplication>
#include <QDate>
#include <QDebug>
#include <QTemporaryDir>
#include <QVariantMap>

#include <cstdio>

#include "database/DatabaseManager.h"

static int s_passed = 0;
static int s_failed = 0;

#define CHECK(cond, msg) \
    do { \
        if (cond) { ++s_passed; } \
        else { ++s_failed; qWarning().noquote() << "FAIL:" << msg; } \
    } while (0)

static void section(const QString &name)
{
    qInfo().noquote() << "\n=== " << name << " ===";
}

// Windows 下默认消息输出可能被吞，强制写 stderr 保证 CI/裸跑可见
static void stderrHandler(QtMsgType, const QMessageLogContext &, const QString &msg)
{
    std::fputs(msg.toLocal8Bit().constData(), stderr);
    std::fputc('\n', stderr);
    std::fflush(stderr);
}

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv); // QSql 驱动插件加载需要应用实例
    qInstallMessageHandler(stderrHandler);
    QTemporaryDir tmp;
    CHECK(tmp.isValid(), "临时目录创建失败");
    DatabaseManager db(tmp.filePath("test.sqlite"));
    CHECK(db.isOpen(), "数据库打开失败: " + db.lastError());

    // ---------- 类别 ----------
    section("类别");
    const int foodId = db.addCategory("餐饮", 0);
    const int busId = db.addCategory("交通", 0);
    const int salaryId = db.addCategory("工资收入", 1);
    CHECK(foodId > 0 && busId > 0 && salaryId > 0, "新增类别应成功");

    CHECK(db.addCategory("餐饮", 0) == -1, "同类型重名类别应被拒绝");
    CHECK(db.addCategory("餐饮", 1) > 0, "不同类型同名类别应允许");
    CHECK(db.addCategory("  ", 0) == -1, "空白名称应被拒绝");
    CHECK(db.addCategory("无效类型", 5) == -1, "非法类型应被拒绝");

    CHECK(db.renameCategory(busId, "公共交通") == true, "类别改名应成功");
    CHECK(db.renameCategory(busId, "餐饮") == false, "改成重名应被拒绝");
    CHECK(db.categories(0).size() == 2, "支出类别应有 2 个（餐饮、公共交通）");
    CHECK(db.categories(1).size() == 2, "收入类别应有 2 个（工资收入、餐饮）");
    CHECK(db.categories(-1).size() == 4, "全部类别应有 4 个");
    const QVariantMap c0 = db.categories(0).at(0).toMap();
    CHECK(c0.contains("color"), "类别应带默认颜色字段");

    // ---------- 付款账户 ----------
    section("付款账户");
    const int wechatId = db.addAccount("微信零钱", "日常零钱");
    const int bankId = db.addAccount("招商银行储蓄卡", "6225 xxxx");
    CHECK(wechatId > 0 && bankId > 0, "新增账户应成功");
    CHECK(db.addAccount("微信零钱") == -1, "重名账户应被拒绝");
    CHECK(db.addAccount("   ") == -1, "空白账户名应被拒绝");
    CHECK(db.updateAccount(bankId, "招行储蓄卡", "工资卡") == true, "账户更新应成功");
    CHECK(db.updateAccount(bankId, "微信零钱", "") == false, "账户改成重名应被拒绝");
    CHECK(db.accounts().size() == 2, "账户应有 2 个");
    const int tmpAccId = db.addAccount("待删除", "");
    CHECK(db.deleteAccount(tmpAccId), "未使用账户应可删除");
    CHECK(db.accounts().size() == 2, "删除后账户应为 2 个");

    // ---------- 账目 ----------
    section("账目");
    const QDate d1(2026, 9, 1);
    const QDate d2(2026, 9, 3);
    const QDate d3(2026, 9, 10);
    const QDate d4(2026, 10, 2);

    CHECK(db.addTransaction(d1, 5, 100, "x", "", foodId, wechatId) == -1, "非法类型应被拒绝");
    CHECK(db.addTransaction(d1, 0, 0, "x", "", foodId, wechatId) == -1, "金额 0 应被拒绝");
    CHECK(db.addTransaction(d1, 0, -500, "x", "", foodId, wechatId) == -1, "负金额应被拒绝");
    CHECK(db.addTransaction(d1, 0, 100, "  ", "", foodId, wechatId) == -1, "空白名称应被拒绝");
    CHECK(db.addTransaction(d1, 0, 100, "x", "", 9999, wechatId) == -1, "不存在的类别应被拒绝");
    CHECK(db.addTransaction(d1, 0, 100, "x", "", foodId, 9999) == -1, "不存在的账户应被拒绝");

    const int t1 = db.addTransaction(d1, 0, 3550, "午饭", "公司食堂", foodId, wechatId);
    const int t2 = db.addTransaction(d1, 0, 600, "地铁", "", busId, wechatId);
    const int t3 = db.addTransaction(d2, 0, 12800, "聚餐", "同学聚会", foodId, bankId);
    const int t4 = db.addTransaction(d3, 0, 4500, "打车", "", busId, bankId);
    const int t5 = db.addTransaction(d3, 1, 5000000, "9月工资", "", salaryId, bankId);
    const int t6 = db.addTransaction(d4, 1, 20000, "理财收益", "货币基金", salaryId, wechatId);
    CHECK(t1 > 0 && t2 > 0 && t3 > 0 && t4 > 0 && t5 > 0 && t6 > 0, "新增账目应成功");

    QVariantList dayList = db.transactionsForDate(d1);
    CHECK(dayList.size() == 2, "9月1日应有 2 笔");
    const QVariantMap row = dayList.at(0).toMap();
    CHECK(row["categoryName"].toString() == "餐饮", "账目应 JOIN 出类别名");
    CHECK(row["accountName"].toString() == "微信零钱", "账目应 JOIN 出账户名");
    CHECK(row["amountCents"].toLongLong() == 3550, "金额应以分返回");

    CHECK(db.updateTransaction(t1, d1, 0, 3600, "午饭", "食堂二楼", foodId, wechatId),
          "账目更新应成功");
    dayList = db.transactionsForDate(d1);
    CHECK(dayList.at(0).toMap()["amountCents"].toLongLong() == 3600, "更新后金额应为 3600");

    CHECK(db.updateTransaction(t1, d1, 0, 3600, "午饭", "", 9999, wechatId) == false,
          "更新为不存在的类别应被拒绝");

    CHECK(db.deleteTransaction(t2), "账目删除应成功");
    CHECK(db.transactionsForDate(d1).size() == 1, "删除后当日剩 1 笔");

    // 引用保护
    CHECK(db.deleteCategory(foodId) == false, "被引用类别不可删除");
    CHECK(db.deleteAccount(bankId) == false, "被引用账户不可删除");

    // 区间查询与筛选
    const QVariantList sep = db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30));
    CHECK(sep.size() == 4, "9月区间应有 4 笔（t1/t3/t4/t5，t2 已删）");
    CHECK(db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30), 1).size() == 1,
          "9月收入应有 1 笔");
    CHECK(db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30), -1, foodId).size() == 2,
          "按类别筛选应有 2 笔餐饮");
    CHECK(db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30), -1, -1, bankId).size() == 3,
          "按账户筛选招行卡应有 3 笔");
    CHECK(db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30), -1, -1, -1, "工资").size()
              == 1,
          "关键字“工资”应命中 1 笔");
    CHECK(db.transactionsInRange(QDate(2026, 9, 1), QDate(2026, 9, 30), -1, -1, -1, "食堂").size()
              == 1,
          "关键字搜索明细应命中 1 笔");

    // ---------- 统计 ----------
    section("统计");
    const QVariantMap s9 = db.rangeSummary(QDate(2026, 9, 1), QDate(2026, 9, 30));
    // 支出: 3600(午饭) + 12800(聚餐) + 4500(打车) = 20900; 收入: 5000000
    CHECK(s9["expenseCents"].toLongLong() == 20900, "9月支出合计应为 20900 分");
    CHECK(s9["incomeCents"].toLongLong() == 5000000, "9月收入合计应为 5000000 分");
    CHECK(s9["netCents"].toLongLong() == 4979100, "9月净额应为 4979100 分");
    CHECK(s9["count"].toInt() == 4, "9月笔数应为 4");

    const QVariantList catBd = db.categoryBreakdown(QDate(2026, 9, 1), QDate(2026, 9, 30), 0);
    CHECK(catBd.size() == 2, "支出类别分布应有 2 组");
    CHECK(catBd.at(0).toMap()["totalCents"].toLongLong() == 16400, "餐饮支出合计应为 16400 分");
    CHECK(catBd.at(0).toMap()["count"].toInt() == 2, "餐饮应有 2 笔");
    CHECK(catBd.at(1).toMap()["name"].toString() == "公共交通", "第二组应为公共交通");

    const QVariantList accBd = db.accountBreakdown(QDate(2026, 9, 1), QDate(2026, 9, 30), 0);
    CHECK(accBd.at(0).toMap()["totalCents"].toLongLong() == 17300, "招行卡支出应为 17300 分");
    CHECK(accBd.at(1).toMap()["totalCents"].toLongLong() == 3600, "微信支出应为 3600 分");

    const QVariantList daily = db.dailyTotals(QDate(2026, 9, 1), QDate(2026, 9, 30));
    CHECK(daily.size() == 3, "9月有账目的日期应为 3 天");
    const QVariantMap d3tot = daily.at(2).toMap();
    CHECK(d3tot["date"].toString() == "2026-09-10", "第三天应为 09-10");
    CHECK(d3tot["expenseCents"].toLongLong() == 4500 && d3tot["incomeCents"].toLongLong() == 5000000,
          "09-10 支出 4500 / 收入 5000000");

    // ---------- 预算 ----------
    section("预算");
    const QString wa = DatabaseManager::weekAnchor(QDate(2026, 9, 3));
    const QString ma = DatabaseManager::monthAnchor(QDate(2026, 9, 3));
    CHECK(wa == "2026-08-31", "2026-09-03 所在周周一应为 08-31");
    CHECK(ma == "2026-09", "月锚点应为 2026-09");

    CHECK(db.setBudget(0, wa, 500000), "设置周预算应成功");
    CHECK(db.setBudget(1, ma, 3000000), "设置月预算应成功");
    CHECK(db.setBudget(0, "bad-anchor", 100) == false, "非法周锚点应被拒绝");
    CHECK(db.setBudget(1, "2026-9", 100) == false, "非法月锚点应被拒绝");
    CHECK(db.setBudget(0, wa, -1) == false, "负预算应被拒绝");

    CHECK(db.budget(0, wa)["amountCents"].toLongLong() == 500000, "读取周预算应为 500000");
    CHECK(db.setBudget(0, wa, 600000), "重复设置同周预算应成功（upsert）");
    CHECK(db.budget(0, wa)["amountCents"].toLongLong() == 600000, "upsert 后应为 600000");
    CHECK(db.budget(0, wa)["anchor"].toString() == wa, "预算锚点应一致");
    CHECK(db.budgets().size() == 2, "预算共 2 条");
    CHECK(db.budgets(0).size() == 1, "周预算 1 条");
    CHECK(db.budget(0, "2030-01-07").isEmpty(), "不存在的预算应返回空 map");

    // ---------- 日期工具 ----------
    section("日期工具");
    const QDate any(2026, 9, 5); // 周六
    CHECK(DatabaseManager::weekStart(any).dayOfWeek() == 1, "weekStart 应为周一");
    CHECK(DatabaseManager::weekStart(any) == QDate(2026, 8, 31), "2026-09-05 所在周应从 08-31 开始");
    CHECK(DatabaseManager::weekEnd(any) == QDate(2026, 9, 6), "该周应到 09-06 结束");
    CHECK(DatabaseManager::monthStart(any) == QDate(2026, 9, 1), "月开始应为 09-01");
    CHECK(DatabaseManager::monthEnd(any) == QDate(2026, 9, 30), "9月应到 09-30 结束");
    CHECK(DatabaseManager::weekStart(QDate(2026, 9, 7)).dayOfWeek() == 1
              && DatabaseManager::weekStart(QDate(2026, 9, 7)) == QDate(2026, 9, 7),
          "周一当天 weekStart 应为自身");

    // ---------- 汇总 ----------
    qInfo().noquote() << "\n================================";
    qInfo().noquote() << "通过:" << s_passed << " 失败:" << s_failed;
    qInfo().noquote() << "================================";
    return s_failed == 0 ? 0 : 1;
}
