import AppIntents

struct SonnetShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RecordExpenseIntent(),
            phrases: [
                "用\(.applicationName)记一笔",
                "在\(.applicationName)里记账",
                "\(.applicationName)记支出",
                "用\(.applicationName)记一笔支出"
            ],
            shortTitle: "快速记账",
            systemImageName: "pencil.line"
        )
        AppShortcut(
            intent: RecordIncomeIntent(),
            phrases: [
                "用\(.applicationName)记收入",
                "\(.applicationName)记一笔收入",
                "告诉\(.applicationName)我收到了钱"
            ],
            shortTitle: "记录收入",
            systemImageName: "plus.circle"
        )
        AppShortcut(
            intent: QueryBalanceIntent(),
            phrases: [
                "用\(.applicationName)查余额",
                "\(.applicationName)这个月花了多少",
                "用\(.applicationName)查本月支出"
            ],
            shortTitle: "查看余额",
            systemImageName: "chart.bar"
        )
    }
}
