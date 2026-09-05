#include <QFont>
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include <cstdio>

#include "database/DatabaseManager.h"

int main(int argc, char *argv[])
{
    // 强制 Basic 样式，保证自绘 Fluent 控件不受系统样式干扰
    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");

    // 自测模式：GUI 程序无控制台，强制输出到 stderr
    if (qEnvironmentVariableIsSet("WIMM_AUTOTEST")) {
        qInstallMessageHandler([](QtMsgType, const QMessageLogContext &, const QString &msg) {
            std::fputs(msg.toLocal8Bit().constData(), stderr);
            std::fputc('\n', stderr);
            std::fflush(stderr);
        });
    }

    QGuiApplication app(argc, argv);
    app.setOrganizationName("WhereIsMyMoney");
    app.setApplicationName("WhereIsMyMoney");
    app.setApplicationVersion("0.2.0");

    QFont font(QStringLiteral("Segoe UI"), 9);
    app.setFont(font);
    app.setWindowIcon(QIcon(QStringLiteral(":/assets/app.ico")));

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
    // 测试辅助：WIMM_OPEN_DIALOG=tx/cat/acc 启动即打开对应对话框
    engine.rootContext()->setContextProperty(
        QStringLiteral("initialOpenDialog"),
        QString::fromLocal8Bit(qgetenv("WIMM_OPEN_DIALOG")));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("WhereIsMyMoney", "Main");

    // 自测模式：跑完 QML 端到端流程后退出（退出码 0 = 全部通过）
    if (qEnvironmentVariableIsSet("WIMM_AUTOTEST")) {
        const QObject *root = engine.rootObjects().isEmpty() ? nullptr
                                                             : engine.rootObjects().first();
        QVariant result = false;
        if (root)
            QMetaObject::invokeMethod(const_cast<QObject *>(root), "runSelfTest",
                                      Q_RETURN_ARG(QVariant, result));
        const bool ok = result.toBool();
        qInfo() << "[AUTOTEST]" << (ok ? "PASS" : "FAIL");
        return ok ? 0 : 1;
    }

    return app.exec();
}
