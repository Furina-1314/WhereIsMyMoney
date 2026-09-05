// 安装脚本：创建开始菜单与桌面快捷方式
function Component()
{
}

Component.prototype.createOperations = function()
{
    // 先执行默认操作（解压数据）
    component.createOperations();

    if (installer.value("os") === "win") {
        // 开始菜单快捷方式
        component.addOperation("CreateShortcut",
            "@TargetDir@/WhereIsMyMoney.exe",
            "@StartMenuDir@/WhereIsMyMoney 记账.lnk",
            "workingDirectory=@TargetDir@",
            "iconPath=@TargetDir@/WhereIsMyMoney.exe",
            "iconId=0",
            "description=WhereIsMyMoney 记账");
        // 桌面快捷方式
        component.addOperation("CreateShortcut",
            "@TargetDir@/WhereIsMyMoney.exe",
            "@DesktopDir@/WhereIsMyMoney 记账.lnk",
            "workingDirectory=@TargetDir@",
            "iconPath=@TargetDir@/WhereIsMyMoney.exe",
            "iconId=0",
            "description=WhereIsMyMoney 记账");
    }
};
