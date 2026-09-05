#include "database/DatabaseManager.h"

#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSqlError>
#include <QStandardPaths>
#include <QUuid>

// QML/C++ 传入的 null QString 会被绑定为 SQL NULL，统一规范化为空串
static QString nz(const QString &s)
{
    return s.isNull() ? QStringLiteral("") : s;
}

// 单条账目行的字段映射（JOIN 类别/账户名称）
static QVariantMap txRow(const QSqlQuery &q)
{
    QVariantMap m;
    m["id"] = q.value("id");
    m["date"] = q.value("date");
    m["type"] = q.value("type");
    m["amountCents"] = q.value("amount");
    m["title"] = q.value("title");
    m["note"] = q.value("note");
    m["categoryId"] = q.value("category_id");
    m["categoryName"] = q.value("category_name");
    m["categoryColor"] = q.value("category_color");
    m["accountId"] = q.value("account_id");
    m["accountName"] = q.value("account_name");
    return m;
}

static const QString kTxSelect = QStringLiteral(
    "SELECT t.id, t.date, t.type, t.amount, t.title, t.note, "
    "       t.category_id, c.name AS category_name, c.color AS category_color, "
    "       t.account_id, a.name AS account_name "
    "FROM transactions t "
    "JOIN categories c ON c.id = t.category_id "
    "JOIN accounts a ON a.id = t.account_id ");

DatabaseManager::DatabaseManager(const QString &databasePath, QObject *parent, bool allowSeed)
    : QObject(parent)
{
    QString path = databasePath;
    if (path.isEmpty()) {
        path = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)
               + QStringLiteral("/whereismymoney.sqlite");
    }
    QDir().mkpath(QFileInfo(path).absolutePath());

    const QString conn = QStringLiteral("wimm-")
                         + QUuid::createUuid().toString(QUuid::WithoutBraces);
    m_db = QSqlDatabase::addDatabase(QStringLiteral("QSQLITE"), conn);
    m_db.setDatabaseName(path);
    if (!m_db.open()) {
        m_lastError = QStringLiteral("无法打开数据库: %1").arg(m_db.lastError().text());
        return;
    }

    QSqlQuery pragma(m_db);
    pragma.exec(QStringLiteral("PRAGMA journal_mode=WAL"));
    pragma.exec(QStringLiteral("PRAGMA foreign_keys=ON"));
    pragma.exec(QStringLiteral("PRAGMA busy_timeout=5000"));

    if (!ensureSchema())
        return;
    if (allowSeed)
        seedDefaultsIfEmpty();
    m_open = true;
}

DatabaseManager::~DatabaseManager()
{
    if (m_db.isOpen())
        m_db.close();
    const QString conn = m_db.connectionName();
    m_db = QSqlDatabase();
    QSqlDatabase::removeDatabase(conn);
}

bool DatabaseManager::ensureSchema()
{
    static const char *kStatements[] = {
        "CREATE TABLE IF NOT EXISTS categories ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL,"
        "  type INTEGER NOT NULL CHECK (type IN (0,1)),"
        "  color TEXT NOT NULL DEFAULT '#0078D7',"
        "  sort_order INTEGER NOT NULL DEFAULT 0,"
        "  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),"
        "  UNIQUE(name, type)"
        ")",
        "CREATE TABLE IF NOT EXISTS accounts ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL UNIQUE,"
        "  note TEXT NOT NULL DEFAULT '',"
        "  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))"
        ")",
        "CREATE TABLE IF NOT EXISTS transactions ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  date TEXT NOT NULL,"
        "  type INTEGER NOT NULL CHECK (type IN (0,1)),"
        "  amount INTEGER NOT NULL CHECK (amount > 0),"
        "  title TEXT NOT NULL,"
        "  note TEXT NOT NULL DEFAULT '',"
        "  category_id INTEGER NOT NULL REFERENCES categories(id),"
        "  account_id INTEGER NOT NULL REFERENCES accounts(id),"
        "  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),"
        "  updated_at TEXT"
        ")",
        "CREATE INDEX IF NOT EXISTS idx_tx_date ON transactions(date)",
        "CREATE INDEX IF NOT EXISTS idx_tx_type ON transactions(type)",
        "CREATE INDEX IF NOT EXISTS idx_tx_category ON transactions(category_id)",
        "CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)",
        "CREATE TABLE IF NOT EXISTS budgets ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  type INTEGER NOT NULL CHECK (type IN (0,1)),"
        "  anchor TEXT NOT NULL,"
        "  amount INTEGER NOT NULL CHECK (amount >= 0),"
        "  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),"
        "  UNIQUE(type, anchor)"
        ")",
    };

    for (const char *sql : kStatements) {
        QSqlQuery q(m_db);
        if (!q.exec(QString::fromLatin1(sql))) {
            m_lastError = QStringLiteral("建表失败: %1").arg(q.lastError().text());
            return false;
        }
    }
    return true;
}

// 首次启动（无任何类别）时写入常用类别与付款账户，用户可自行增删
void DatabaseManager::seedDefaultsIfEmpty()
{
    QSqlQuery check(m_db);
    if (!check.exec(QStringLiteral("SELECT COUNT(*) FROM categories")) || !check.next())
        return;
    if (check.value(0).toInt() > 0)
        return;

    struct Cat { const char *name; int type; const char *color; };
    static const Cat kCats[] = {
        { "餐饮", Expense, "#E81123" }, { "交通", Expense, "#0078D7" },
        { "购物", Expense, "#B146C2" }, { "娱乐", Expense, "#FF8C00" },
        { "居住", Expense, "#008272" }, { "医疗", Expense, "#E3008C" },
        { "教育", Expense, "#744DA9" }, { "其他支出", Expense, "#68768A" },
        { "工资", Income, "#10893E" },  { "奖金", Income, "#00B294" },
        { "理财", Income, "#0078D7" },  { "红包", Income, "#EF6950" },
    };
    for (const Cat &c : kCats) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("INSERT OR IGNORE INTO categories(name, type, color) VALUES(?,?,?)"));
        q.addBindValue(QString::fromUtf8(c.name));
        q.addBindValue(c.type);
        q.addBindValue(QString::fromLatin1(c.color));
        q.exec();
    }

    static const char *kAccounts[] = { "现金", "微信零钱", "支付宝", "银行卡" };
    for (const char *a : kAccounts) {
        QSqlQuery q(m_db);
        q.prepare(QStringLiteral("INSERT OR IGNORE INTO accounts(name) VALUES(?)"));
        q.addBindValue(QString::fromUtf8(a));
        q.exec();
    }
}

// 演示用示例账目（仅在测试库上由 main.cpp 调用；库内已有账目则跳过）
void DatabaseManager::seedSampleTransactions()
{
    QSqlQuery check(m_db);
    if (!check.exec(QStringLiteral("SELECT COUNT(*) FROM transactions")) || !check.next())
        return;
    if (check.value(0).toInt() > 0)
        return;

    auto idOf = [this](const QString &table, const QString &name, int type = -1) -> int {
        QSqlQuery q(m_db);
        if (type >= 0)
            q.prepare(QStringLiteral("SELECT id FROM %1 WHERE name=? AND type=?").arg(table));
        else
            q.prepare(QStringLiteral("SELECT id FROM %1 WHERE name=?").arg(table));
        q.addBindValue(name);
        if (type >= 0)
            q.addBindValue(type);
        q.exec();
        return q.next() ? q.value(0).toInt() : -1;
    };

    const int food = idOf(QStringLiteral("categories"), QStringLiteral("餐饮"), Expense);
    const int bus = idOf(QStringLiteral("categories"), QStringLiteral("交通"), Expense);
    const int fun = idOf(QStringLiteral("categories"), QStringLiteral("娱乐"), Expense);
    const int shop = idOf(QStringLiteral("categories"), QStringLiteral("购物"), Expense);
    const int licai = idOf(QStringLiteral("categories"), QStringLiteral("理财"), Income);
    const int wechat = idOf(QStringLiteral("accounts"), QStringLiteral("微信零钱"));
    const int alipay = idOf(QStringLiteral("accounts"), QStringLiteral("支付宝"));
    const int cash = idOf(QStringLiteral("accounts"), QStringLiteral("现金"));
    const int bank = idOf(QStringLiteral("accounts"), QStringLiteral("银行卡"));

    const QDate today = QDate::currentDate();
    if (food > 0 && wechat > 0)
        addTransaction(today, Expense, 3550, QStringLiteral("午饭"), QStringLiteral("公司食堂"), food, wechat);
    if (bus > 0 && alipay > 0)
        addTransaction(today, Expense, 600, QStringLiteral("地铁"), QString(), bus, alipay);
    if (bus > 0 && cash > 0)
        addTransaction(today.addDays(-1), Expense, 2380, QStringLiteral("打车回家"),
                       QStringLiteral("下雨"), bus, cash);
    if (licai > 0 && alipay > 0)
        addTransaction(today, Income, 5230, QStringLiteral("理财收益"),
                       QStringLiteral("货币基金"), licai, alipay);
    if (fun > 0 && wechat > 0)
        addTransaction(today.addDays(-3), Expense, 4280, QStringLiteral("电影票"),
                       QStringLiteral("周末"), fun, wechat);
    if (shop > 0 && bank > 0)
        addTransaction(today.addDays(-3), Expense, 15600, QStringLiteral("超市采购"), QString(), shop, bank);
    if (bus > 0 && alipay > 0)
        addTransaction(today.addDays(-6), Expense, 4500, QStringLiteral("公交通勤"), QString(), bus, alipay);
    if (shop > 0 && bank > 0)
        addTransaction(today.addDays(-10), Expense, 8990, QStringLiteral("网购衣服"), QStringLiteral("换季"), shop, bank);
    if (fun > 0 && wechat > 0)
        addTransaction(today.addDays(-2), Expense, 3000, QStringLiteral("游戏充值"), QString(), fun, wechat);
}

QSqlQuery DatabaseManager::run(const QString &sql, const QVariantList &binds)
{
    QSqlQuery q(m_db);
    q.prepare(sql);
    for (const QVariant &v : binds)
        q.addBindValue(v);
    if (!q.exec())
        m_lastError = q.lastError().databaseText();
    return q;
}

QSqlQuery DatabaseManager::run(const QString &sql, const QVariantList &binds) const
{
    QSqlQuery q(m_db);
    q.prepare(sql);
    for (const QVariant &v : binds)
        q.addBindValue(v);
    if (!q.exec())
        qFatal("只读查询失败: %s", qPrintable(q.lastError().text()));
    return q;
}

bool DatabaseManager::exists(const QString &table, int id) const
{
    QSqlQuery q = run(QStringLiteral("SELECT 1 FROM %1 WHERE id=?").arg(table), {id});
    return q.next();
}

// ---------------- 类别 ----------------

int DatabaseManager::addCategory(const QString &name, int type, const QString &color)
{
    const QString n = name.trimmed();
    if (n.isEmpty()) {
        m_lastError = QStringLiteral("类别名称不能为空");
        return -1;
    }
    if (type != Expense && type != Income) {
        m_lastError = QStringLiteral("类别类型无效");
        return -1;
    }
    QSqlQuery q = run(QStringLiteral("INSERT INTO categories(name, type, color) VALUES(?,?,?)"),
                      {n, type, color.isEmpty() ? QStringLiteral("#0078D7") : color});
    if (!q.isActive()) {
        if (m_lastError.contains(QLatin1String("UNIQUE")))
            m_lastError = QStringLiteral("同名类别已存在: %1").arg(n);
        return -1;
    }
    emit dataChanged();
    return q.lastInsertId().toInt();
}

bool DatabaseManager::renameCategory(int id, const QString &newName)
{
    const QString n = newName.trimmed();
    if (n.isEmpty()) {
        m_lastError = QStringLiteral("类别名称不能为空");
        return false;
    }
    QSqlQuery q = run(QStringLiteral("UPDATE categories SET name=? WHERE id=?"), {n, id});
    if (!q.isActive()) {
        if (m_lastError.contains(QLatin1String("UNIQUE")))
            m_lastError = QStringLiteral("同名类别已存在: %1").arg(n);
        return false;
    }
    const bool ok = q.numRowsAffected() > 0;
    if (ok)
        emit dataChanged();
    return ok;
}

bool DatabaseManager::deleteCategory(int id)
{
    QSqlQuery used = run(QStringLiteral("SELECT COUNT(*) FROM transactions WHERE category_id=?"), {id});
    if (used.next() && used.value(0).toInt() > 0) {
        m_lastError = QStringLiteral("该类别已被账目使用，无法删除");
        return false;
    }
    QSqlQuery q = run(QStringLiteral("DELETE FROM categories WHERE id=?"), {id});
    if (!q.isActive() || q.numRowsAffected() == 0) {
        m_lastError = QStringLiteral("类别不存在");
        return false;
    }
    emit dataChanged();
    return true;
}

QVariantList DatabaseManager::categories(int type) const
{
    QString sql = QStringLiteral("SELECT id, name, type, color, sort_order FROM categories");
    QVariantList binds;
    if (type == Expense || type == Income) {
        sql += QStringLiteral(" WHERE type=?");
        binds << type;
    }
    sql += QStringLiteral(" ORDER BY type, sort_order, id");
    QVariantList list;
    QSqlQuery q = run(sql, binds);
    while (q.next()) {
        QVariantMap m;
        m["id"] = q.value(0);
        m["name"] = q.value(1);
        m["type"] = q.value(2);
        m["color"] = q.value(3);
        list.append(m);
    }
    return list;
}

// ---------------- 付款账户 ----------------

int DatabaseManager::addAccount(const QString &name, const QString &note)
{
    const QString n = name.trimmed();
    if (n.isEmpty()) {
        m_lastError = QStringLiteral("账户名称不能为空");
        return -1;
    }
    QSqlQuery q = run(QStringLiteral("INSERT INTO accounts(name, note) VALUES(?,?)"),
                      {n, nz(note).trimmed()});
    if (!q.isActive()) {
        if (m_lastError.contains(QLatin1String("UNIQUE")))
            m_lastError = QStringLiteral("同名账户已存在: %1").arg(n);
        return -1;
    }
    emit dataChanged();
    return q.lastInsertId().toInt();
}

bool DatabaseManager::updateAccount(int id, const QString &name, const QString &note)
{
    const QString n = name.trimmed();
    if (n.isEmpty()) {
        m_lastError = QStringLiteral("账户名称不能为空");
        return false;
    }
    QSqlQuery q = run(QStringLiteral("UPDATE accounts SET name=?, note=? WHERE id=?"),
                      {n, nz(note).trimmed(), id});
    if (!q.isActive()) {
        if (m_lastError.contains(QLatin1String("UNIQUE")))
            m_lastError = QStringLiteral("同名账户已存在: %1").arg(n);
        return false;
    }
    const bool ok = q.numRowsAffected() > 0;
    if (ok)
        emit dataChanged();
    return ok;
}

bool DatabaseManager::deleteAccount(int id)
{
    QSqlQuery used = run(QStringLiteral("SELECT COUNT(*) FROM transactions WHERE account_id=?"), {id});
    if (used.next() && used.value(0).toInt() > 0) {
        m_lastError = QStringLiteral("该账户已被账目使用，无法删除");
        return false;
    }
    QSqlQuery q = run(QStringLiteral("DELETE FROM accounts WHERE id=?"), {id});
    if (!q.isActive() || q.numRowsAffected() == 0) {
        m_lastError = QStringLiteral("账户不存在");
        return false;
    }
    emit dataChanged();
    return true;
}

QVariantList DatabaseManager::accounts() const
{
    QVariantList list;
    QSqlQuery q = run(QStringLiteral("SELECT id, name, note FROM accounts ORDER BY id"));
    while (q.next()) {
        QVariantMap m;
        m["id"] = q.value(0);
        m["name"] = q.value(1);
        m["note"] = q.value(2);
        list.append(m);
    }
    return list;
}

// ---------------- 账目 ----------------

int DatabaseManager::addTransaction(const QDate &date, int type, qint64 amountCents,
                                    const QString &title, const QString &note,
                                    int categoryId, int accountId)
{
    if (!date.isValid()) {
        m_lastError = QStringLiteral("日期无效");
        return -1;
    }
    if (type != Expense && type != Income) {
        m_lastError = QStringLiteral("账目类型无效");
        return -1;
    }
    if (amountCents <= 0) {
        m_lastError = QStringLiteral("金额必须大于 0");
        return -1;
    }
    if (title.trimmed().isEmpty()) {
        m_lastError = QStringLiteral("账目名称不能为空");
        return -1;
    }
    if (!exists(QStringLiteral("categories"), categoryId)) {
        m_lastError = QStringLiteral("类别不存在");
        return -1;
    }
    if (!exists(QStringLiteral("accounts"), accountId)) {
        m_lastError = QStringLiteral("账户不存在");
        return -1;
    }
    QSqlQuery q = run(QStringLiteral(
                          "INSERT INTO transactions(date, type, amount, title, note, category_id, account_id) "
                          "VALUES(?,?,?,?,?,?,?)"),
                      {date.toString(Qt::ISODate), type, amountCents,
                       title.trimmed(), nz(note).trimmed(), categoryId, accountId});
    if (!q.isActive())
        return -1;
    emit dataChanged();
    return q.lastInsertId().toInt();
}

bool DatabaseManager::updateTransaction(int id, const QDate &date, int type, qint64 amountCents,
                                        const QString &title, const QString &note,
                                        int categoryId, int accountId)
{
    if (!date.isValid()) {
        m_lastError = QStringLiteral("日期无效");
        return false;
    }
    if (type != Expense && type != Income) {
        m_lastError = QStringLiteral("账目类型无效");
        return false;
    }
    if (amountCents <= 0) {
        m_lastError = QStringLiteral("金额必须大于 0");
        return false;
    }
    if (title.trimmed().isEmpty()) {
        m_lastError = QStringLiteral("账目名称不能为空");
        return false;
    }
    if (!exists(QStringLiteral("categories"), categoryId)) {
        m_lastError = QStringLiteral("类别不存在");
        return false;
    }
    if (!exists(QStringLiteral("accounts"), accountId)) {
        m_lastError = QStringLiteral("账户不存在");
        return false;
    }
    QSqlQuery q = run(QStringLiteral(
                          "UPDATE transactions SET date=?, type=?, amount=?, title=?, note=?, "
                          "category_id=?, account_id=?, updated_at=datetime('now','localtime') "
                          "WHERE id=?"),
                      {date.toString(Qt::ISODate), type, amountCents,
                       title.trimmed(), nz(note).trimmed(), categoryId, accountId, id});
    const bool ok = q.isActive() && q.numRowsAffected() > 0;
    if (ok)
        emit dataChanged();
    return ok;
}

bool DatabaseManager::deleteTransaction(int id)
{
    QSqlQuery q = run(QStringLiteral("DELETE FROM transactions WHERE id=?"), {id});
    const bool ok = q.isActive() && q.numRowsAffected() > 0;
    if (ok)
        emit dataChanged();
    return ok;
}

QVariantList DatabaseManager::transactionsForDate(const QDate &date) const
{
    QVariantList list;
    QSqlQuery q = run(kTxSelect + QStringLiteral(" WHERE t.date=? ORDER BY t.id"),
                      {date.toString(Qt::ISODate)});
    while (q.next())
        list.append(txRow(q));
    return list;
}

QVariantList DatabaseManager::transactionsInRange(const QDate &from, const QDate &to,
                                                  int type, int categoryId, int accountId,
                                                  const QString &keyword) const
{
    QString sql = kTxSelect + QStringLiteral(" WHERE t.date BETWEEN ? AND ?");
    QVariantList binds{from.toString(Qt::ISODate), to.toString(Qt::ISODate)};
    if (type == Expense || type == Income) {
        sql += QStringLiteral(" AND t.type=?");
        binds << type;
    }
    if (categoryId > 0) {
        sql += QStringLiteral(" AND t.category_id=?");
        binds << categoryId;
    }
    if (accountId > 0) {
        sql += QStringLiteral(" AND t.account_id=?");
        binds << accountId;
    }
    const QString kw = keyword.trimmed();
    if (!kw.isEmpty()) {
        sql += QStringLiteral(" AND (t.title LIKE ? OR t.note LIKE ?)");
        binds << QStringLiteral("%%1%").arg(kw) << QStringLiteral("%%1%").arg(kw);
    }
    sql += QStringLiteral(" ORDER BY t.date DESC, t.id DESC");

    QVariantList list;
    QSqlQuery q = run(sql, binds);
    while (q.next())
        list.append(txRow(q));
    return list;
}

// ---------------- 统计 ----------------

QVariantMap DatabaseManager::rangeSummary(const QDate &from, const QDate &to) const
{
    QVariantMap m;
    QSqlQuery q = run(QStringLiteral(
                          "SELECT COALESCE(SUM(CASE WHEN type=0 THEN amount END),0),"
                          "       COALESCE(SUM(CASE WHEN type=1 THEN amount END),0),"
                          "       COUNT(*) "
                          "FROM transactions WHERE date BETWEEN ? AND ?"),
                      {from.toString(Qt::ISODate), to.toString(Qt::ISODate)});
    if (q.next()) {
        const qint64 expense = q.value(0).toLongLong();
        const qint64 income = q.value(1).toLongLong();
        m["expenseCents"] = expense;
        m["incomeCents"] = income;
        m["netCents"] = income - expense;
        m["count"] = q.value(2).toInt();
    }
    return m;
}

QVariantList DatabaseManager::categoryBreakdown(const QDate &from, const QDate &to, int type) const
{
    QVariantList list;
    QSqlQuery q = run(QStringLiteral(
                          "SELECT c.id, c.name, c.color, SUM(t.amount) AS total, COUNT(*) AS cnt "
                          "FROM transactions t JOIN categories c ON c.id=t.category_id "
                          "WHERE t.date BETWEEN ? AND ? AND t.type=? "
                          "GROUP BY c.id ORDER BY total DESC"),
                      {from.toString(Qt::ISODate), to.toString(Qt::ISODate), type});
    while (q.next()) {
        QVariantMap m;
        m["categoryId"] = q.value(0);
        m["name"] = q.value(1);
        m["color"] = q.value(2);
        m["totalCents"] = q.value(3);
        m["count"] = q.value(4);
        list.append(m);
    }
    return list;
}

QVariantList DatabaseManager::accountBreakdown(const QDate &from, const QDate &to, int type) const
{
    QVariantList list;
    QSqlQuery q = run(QStringLiteral(
                          "SELECT a.id, a.name, SUM(t.amount) AS total, COUNT(*) AS cnt "
                          "FROM transactions t JOIN accounts a ON a.id=t.account_id "
                          "WHERE t.date BETWEEN ? AND ? AND t.type=? "
                          "GROUP BY a.id ORDER BY total DESC"),
                      {from.toString(Qt::ISODate), to.toString(Qt::ISODate), type});
    while (q.next()) {
        QVariantMap m;
        m["accountId"] = q.value(0);
        m["name"] = q.value(1);
        m["totalCents"] = q.value(2);
        m["count"] = q.value(3);
        list.append(m);
    }
    return list;
}

QVariantList DatabaseManager::dailyTotals(const QDate &from, const QDate &to) const
{
    QVariantList list;
    QSqlQuery q = run(QStringLiteral(
                          "SELECT date,"
                          "  COALESCE(SUM(CASE WHEN type=0 THEN amount END),0),"
                          "  COALESCE(SUM(CASE WHEN type=1 THEN amount END),0) "
                          "FROM transactions WHERE date BETWEEN ? AND ? "
                          "GROUP BY date ORDER BY date"),
                      {from.toString(Qt::ISODate), to.toString(Qt::ISODate)});
    while (q.next()) {
        QVariantMap m;
        m["date"] = q.value(0).toString();
        m["expenseCents"] = q.value(1).toLongLong();
        m["incomeCents"] = q.value(2).toLongLong();
        list.append(m);
    }
    return list;
}

// ---------------- 预算 ----------------

bool DatabaseManager::setBudget(int budgetType, const QString &anchor, qint64 amountCents)
{
    if (budgetType != WeeklyBudget && budgetType != MonthlyBudget) {
        m_lastError = QStringLiteral("预算类型无效");
        return false;
    }
    if (budgetType == WeeklyBudget && !QDate::fromString(anchor, Qt::ISODate).isValid()) {
        m_lastError = QStringLiteral("周预算锚点须为 yyyy-MM-dd");
        return false;
    }
    if (budgetType == MonthlyBudget
        && !QRegularExpression(QStringLiteral("^\\d{4}-\\d{2}$")).match(anchor).hasMatch()) {
        m_lastError = QStringLiteral("月预算锚点须为 yyyy-MM");
        return false;
    }
    if (amountCents < 0) {
        m_lastError = QStringLiteral("预算金额不能为负");
        return false;
    }
    QSqlQuery q = run(QStringLiteral(
                          "INSERT INTO budgets(type, anchor, amount) VALUES(?,?,?) "
                          "ON CONFLICT(type, anchor) DO UPDATE SET amount=excluded.amount"),
                      {budgetType, anchor, amountCents});
    const bool ok = q.isActive();
    if (ok)
        emit dataChanged();
    return ok;
}

QVariantMap DatabaseManager::budget(int budgetType, const QString &anchor) const
{
    QVariantMap m;
    QSqlQuery q = run(QStringLiteral("SELECT id, type, anchor, amount FROM budgets "
                                     "WHERE type=? AND anchor=?"),
                      {budgetType, anchor});
    if (q.next()) {
        m["id"] = q.value(0);
        m["type"] = q.value(1);
        m["anchor"] = q.value(2);
        m["amountCents"] = q.value(3).toLongLong();
    }
    return m;
}

QVariantList DatabaseManager::budgets(int budgetType) const
{
    QString sql = QStringLiteral("SELECT id, type, anchor, amount FROM budgets");
    QVariantList binds;
    if (budgetType == WeeklyBudget || budgetType == MonthlyBudget) {
        sql += QStringLiteral(" WHERE type=?");
        binds << budgetType;
    }
    sql += QStringLiteral(" ORDER BY type, anchor");
    QVariantList list;
    QSqlQuery q = run(sql, binds);
    while (q.next()) {
        QVariantMap m;
        m["id"] = q.value(0);
        m["type"] = q.value(1);
        m["anchor"] = q.value(2);
        m["amountCents"] = q.value(3).toLongLong();
        list.append(m);
    }
    return list;
}

// ---------------- 日期工具 ----------------

QDate DatabaseManager::weekStart(const QDate &date)
{
    return date.addDays(-(date.dayOfWeek() - 1)); // dayOfWeek: 周一=1 .. 周日=7
}

QDate DatabaseManager::weekEnd(const QDate &date)
{
    return weekStart(date).addDays(6);
}

QDate DatabaseManager::monthStart(const QDate &date)
{
    return QDate(date.year(), date.month(), 1);
}

QDate DatabaseManager::monthEnd(const QDate &date)
{
    return QDate(date.year(), date.month(), 1).addMonths(1).addDays(-1);
}

QString DatabaseManager::weekAnchor(const QDate &date)
{
    return weekStart(date).toString(Qt::ISODate);
}

QString DatabaseManager::monthAnchor(const QDate &date)
{
    return QStringLiteral("%1-%2").arg(date.year()).arg(date.month(), 2, 10, QChar('0'));
}
