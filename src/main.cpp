#include <QFont>
#include <QGuiApplication>
#include <QQmlApplicationEngine>

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

    QQmlApplicationEngine engine;
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed,
                     &app, []() { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("WhereIsMyMoney", "Main");

    return app.exec();
}
