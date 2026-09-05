#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "database/DatabaseManager.h"

int main(int argc, char *argv[])
{
    // 强制 Basic 样式，保证自绘 Fluent 控件不受系统样式干扰
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");

    QGuiApplication app(argc, argv);
    app.setOrganizationName("WhereIsMyMoney");
    app.setApplicationName("WhereIsMyMoney");
    app.setApplicationVersion("0.1.0");

    QFont font(QStringLiteral("Segoe UI"), 9);
    app.setFont(font);

    // 数据层（默认位于 AppData；WIMM_TEST_DB 可指向临时测试库）
    const QString dbPath = QString::fromLocal8Bit(qgetenv("WIMM_TEST_DB"));
    DatabaseManager database(dbPath);
    if (!database.isOpen())
        qWarning() << "数据库初始化失败:" << database.lastError();
    if (!dbPath.isEmpty() && qEnvironmentVariableIsSet("WIMM_SEED_TX"))
        database.seedSampleTransactions();

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("DB"), &database);
    // 测试辅助：WIMM_START_PAGE 指定起始页索引，WIMM_THEME 强制外观(light/dark)
    engine.rootContext()->setContextProperty(
        QStringLiteral("initialPage"),
        qEnvironmentVariableIntValue("WIMM_START_PAGE"));
    engine.rootContext()->setContextProperty(
        QStringLiteral("initialTheme"),
        QString::fromLocal8Bit(qgetenv("WIMM_THEME")));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("WhereIsMyMoney", "Main");

    return app.exec();
}
