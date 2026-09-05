#pragma once

#include <QDate>
#include <QObject>
#include <QSqlDatabase>
#include <QSqlQuery>
#include <QString>
#include <QVariantList>
#include <QVariantMap>

/**
 * 数据层核心：SQLite 建库建表，账目/类别/付款账户/预算的增删改查与统计。
 *
 * 约定：
 * - 金额一律以“分”（qint64 整数）存储与传递，避免浮点误差；要求 > 0。
 * - 账目 type：0 = 支出，1 = 收入（TxType）。
 * - 预算 type：0 = 周预算，1 = 月预算（BudgetType）；周以周一日期为锚点，
 *   月以 "yyyy-MM" 为锚点；预算按支出统计。
 */
class DatabaseManager : public QObject
{
    Q_OBJECT

public:
    enum TxType { Expense = 0, Income = 1 };
    enum BudgetType { WeeklyBudget = 0, MonthlyBudget = 1 };

    // databasePath 为空时使用 AppData 默认库；allowSeed=false 时不写入默认类别/账户（测试用）
    explicit DatabaseManager(const QString &databasePath = QString(), QObject *parent = nullptr,
                             bool allowSeed = true);
    ~DatabaseManager() override;

signals:
    void dataChanged(); // 任何成功的数据变更后发出（QML 绑定据此刷新）

public:
    bool isOpen() const { return m_open; }
    Q_INVOKABLE QString lastError() const { return m_lastError; }

    // 测试辅助：无账目时写入示例账目（演示/截图用，不进生产路径）
    void seedSampleTransactions();

    // ---------- 类别 ----------
    Q_INVOKABLE int addCategory(const QString &name, int type, const QString &color = QString());
    Q_INVOKABLE bool renameCategory(int id, const QString &newName);
    Q_INVOKABLE bool deleteCategory(int id);          // 被账目引用时拒绝删除
    Q_INVOKABLE QVariantList categories(int type = -1) const;

    // ---------- 付款账户（支出来源/收入流向：银行卡、微信零钱等） ----------
    Q_INVOKABLE int addAccount(const QString &name, const QString &note = QString());
    Q_INVOKABLE bool updateAccount(int id, const QString &name, const QString &note);
    Q_INVOKABLE bool deleteAccount(int id);           // 被账目引用时拒绝删除
    Q_INVOKABLE QVariantList accounts() const;

    // ---------- 账目 ----------
    Q_INVOKABLE int addTransaction(const QDate &date, int type, qint64 amountCents,
                       const QString &title, const QString &note,
                       int categoryId, int accountId);
    Q_INVOKABLE bool updateTransaction(int id, const QDate &date, int type, qint64 amountCents,
                           const QString &title, const QString &note,
                           int categoryId, int accountId);
    Q_INVOKABLE bool deleteTransaction(int id);
    Q_INVOKABLE QVariantList transactionsForDate(const QDate &date) const;
    Q_INVOKABLE QVariantList transactionsInRange(const QDate &from, const QDate &to,
                                     int type = -1, int categoryId = -1,
                                     int accountId = -1,
                                     const QString &keyword = QString()) const;

    // ---------- 统计 ----------
    Q_INVOKABLE QVariantMap rangeSummary(const QDate &from, const QDate &to) const;
    Q_INVOKABLE QVariantList categoryBreakdown(const QDate &from, const QDate &to, int type) const;
    Q_INVOKABLE QVariantList accountBreakdown(const QDate &from, const QDate &to, int type) const;
    Q_INVOKABLE QVariantList dailyTotals(const QDate &from, const QDate &to) const;

    // ---------- 预算 ----------
    Q_INVOKABLE bool setBudget(int budgetType, const QString &anchor, qint64 amountCents);
    Q_INVOKABLE bool clearBudget(int budgetType, const QString &anchor); // 删除预算
    Q_INVOKABLE QVariantMap budget(int budgetType, const QString &anchor) const;

    // ---------- 分预算（预算内按类别细分） ----------
    Q_INVOKABLE QVariantList budgetItems(int budgetId) const;
    Q_INVOKABLE bool setBudgetItem(int budgetId, int categoryId, qint64 amountCents);
    Q_INVOKABLE bool clearBudgetItem(int budgetId, int categoryId);
    Q_INVOKABLE QVariantList budgets(int budgetType = -1) const;

    // ---------- 日期工具（周一为一周开始） ----------
    static QDate weekStart(const QDate &date);
    static QDate weekEnd(const QDate &date);
    static QDate monthStart(const QDate &date);
    static QDate monthEnd(const QDate &date);
    static QString weekAnchor(const QDate &date);  // "yyyy-MM-dd"（周一）
    static QString monthAnchor(const QDate &date); // "yyyy-MM"

private:
    bool ensureSchema();
    void seedDefaultsIfEmpty(); // 首次启动写入默认类别/付款账户
    QSqlQuery run(const QString &sql, const QVariantList &binds = QVariantList());
    QSqlQuery run(const QString &sql, const QVariantList &binds = QVariantList()) const;
    bool exists(const QString &table, int id) const;

    QSqlDatabase m_db;
    bool m_open = false;
    QString m_lastError;
};
