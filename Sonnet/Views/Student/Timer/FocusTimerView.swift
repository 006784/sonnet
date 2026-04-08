import SwiftUI
import SwiftData
import UserNotifications
import AudioToolbox

// MARK: - Phase

private enum FocusPhase: Equatable { case idle, running, paused, done }

// MARK: - Main View

struct FocusTimerView: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase)   private var scenePhase

    @Query(sort: \FocusSession.startTime, order: .reverse)
    private var sessions: [FocusSession]

    @Query(sort: \Course.name)
    private var courses: [Course]

    // ── Timer State ─────────────────────────────────────
    @State private var phase: FocusPhase = .idle
    @State private var selectedMinutes = 25
    @State private var totalSeconds    = 1500
    @State private var remaining       = 1500
    @State private var timerRef: Timer? = nil
    @State private var currentSession: FocusSession? = nil
    @State private var backgroundedAt: Date? = nil

    // ── UI State ─────────────────────────────────────────
    @State private var selectedCourse = ""
    @State private var showSettings   = false
    @State private var quoteIndex     = 0
    @State private var showDoneCheck  = false

    // ── Settings (AppStorage) ────────────────────────────
    @AppStorage("timer_sound_enabled") private var soundEnabled = true

    // ── Poetry Quotes ────────────────────────────────────
    private let quotes = [
        "静水流深，笔墨生花",
        "行到水穷处，坐看云起时",
        "千里之行，始于足下",
        "博观而约取，厚积而薄发",
        "不积跬步，无以至千里",
    ]
    private let durations = [15, 25, 45, 60]

    // ── Computed ─────────────────────────────────────────
    private var progress: Double {
        Double(remaining) / Double(max(totalSeconds, 1))
    }
    private var ringColor: Color {
        if phase == .done { return SonnetColors.jade }
        if phase == .running && remaining < 300 { return SonnetColors.amber }
        return SonnetColors.ink
    }
    private var isActive: Bool { phase == .running || phase == .paused }
    private var todaySessions: [FocusSession] {
        let start = Calendar.current.startOfDay(for: Date())
        return sessions.filter { $0.startTime >= start && $0.isCompleted }
    }
    private var todayCount: Int { todaySessions.count }
    private var todayMinutes: Int {
        todaySessions.reduce(0) { $0 + $1.duration } / 60
    }
    private var streakDays: Int {
        let cal  = Calendar.current
        var day  = cal.startOfDay(for: Date())
        let days = Set(sessions.filter { $0.isCompleted }
                        .map { cal.startOfDay(for: $0.startTime) })
        var n = 0
        while days.contains(day) {
            n += 1
            day = cal.date(byAdding: .day, value: -1, to: day) ?? day
        }
        return n
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // 背景渐变层
            SonnetColors.paper.ignoresSafeArea()
            if isActive {
                SonnetColors.inkWash.ignoresSafeArea()
                    .transition(.opacity)
            }

            // 主内容
            ScrollView(showsIndicators: false) {
                VStack(spacing: SonnetDimens.spacingXXL) {
                    ringSection
                        .padding(.top, SonnetDimens.spacingXXL)

                    if isActive {
                        quoteSection
                    }

                    controlSection

                    todayStatsSection

                    if sessions.count > 0 {
                        weeklyChartSection
                    }

                    Spacer(minLength: 40)
                }
            }

            // 完成遮罩
            if phase == .done {
                doneOverlay
                    .transition(.opacity)
            }
        }
        .animation(SonnetMotion.springSlow, value: isActive)
        .animation(SonnetMotion.spring, value: phase)
        .navigationTitle("专注计时")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            TimerSettingsSheet(totalSeconds: $totalSeconds)
                .onDisappear {
                    selectedMinutes = totalSeconds / 60
                    if phase == .idle { remaining = totalSeconds }
                }
        }
        .onDisappear { stopTimer() }
        .onChange(of: scenePhase) { _, new in handleScenePhase(new) }
        .onChange(of: remaining)  { _, new in tickQuote(new) }
    }

    // MARK: - Ring Section

    private var ringSection: some View {
        ZStack {
            Circle()
                .stroke(SonnetColors.paperLine, lineWidth: 6)
                .frame(width: 200, height: 200)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(ringColor,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 200, height: 200)
                .animation(SonnetMotion.spring, value: progress)
                .animation(SonnetMotion.spring, value: ringColor)

            VStack(spacing: 6) {
                Text(timeString(remaining))
                    .font(.system(size: 42, weight: .semibold, design: .rounded))
                    .tracking(-1.5)
                    .foregroundStyle(SonnetColors.textTitle)
                    .contentTransition(.numericText())

                Text(phaseLabel)
                    .font(SonnetTypography.caption1)
                    .foregroundStyle(SonnetColors.textCaption)
            }
        }
    }

    private var phaseLabel: String {
        switch phase {
        case .idle:    return "专注"
        case .running: return "专注中"
        case .paused:  return "已暂停"
        case .done:    return "完成"
        }
    }

    // MARK: - Quote Section

    private var quoteSection: some View {
        Text(quotes[quoteIndex % quotes.count])
            .font(SonnetTypography.caption1)
            .foregroundStyle(SonnetColors.ink.opacity(0.50))
            .multilineTextAlignment(.center)
            .id(quoteIndex)
            .transition(.opacity)
            .animation(SonnetMotion.springSlow, value: quoteIndex)
            .padding(.horizontal, SonnetDimens.spacingXXL)
    }

    // MARK: - Control Section

    @ViewBuilder
    private var controlSection: some View {
        switch phase {
        case .idle:          idleControls
        case .running, .paused: activeControls
        case .done:          EmptyView()
        }
    }

    private var idleControls: some View {
        VStack(spacing: SonnetDimens.spacingL) {
            // 时长选择
            HStack(spacing: 8) {
                ForEach(durations, id: \.self) { min in
                    durationCapsule(min)
                }
            }

            // 课程关联
            if !courses.isEmpty { courseSelector }

            // 开始按钮
            InkButton(title: "开始专注", action: start)
                .frame(width: 280)
                .padding(.horizontal, SonnetDimens.spacingXL)
        }
    }

    private var activeControls: some View {
        VStack(spacing: SonnetDimens.spacingM) {
            // 暂停 / 继续
            Button {
                if phase == .running { pause() } else { resume() }
            } label: {
                ZStack {
                    Circle()
                        .fill(SonnetColors.ink)
                        .frame(width: 56, height: 56)
                        .shadow(color: SonnetColors.ink.opacity(0.3), radius: 8, y: 4)
                    Image(systemName: phase == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            // 放弃
            Button("放弃本次", action: abandon)
                .font(.system(size: 13))
                .foregroundStyle(SonnetColors.textHint)
        }
    }

    // MARK: - Duration Capsule

    private func durationCapsule(_ min: Int) -> some View {
        let sel = selectedMinutes == min
        return Button {
            guard phase == .idle else { return }
            selectedMinutes = min
            totalSeconds    = min * 60
            remaining       = totalSeconds
            HapticManager.selection()
        } label: {
            Text("\(min) 分")
                .font(.system(size: 13, weight: sel ? .semibold : .regular))
                .foregroundStyle(sel ? SonnetColors.textOnInk : SonnetColors.textSecond)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(sel ? SonnetColors.ink : SonnetColors.paperCream))
        }
    }

    // MARK: - Course Selector

    private var courseSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                courseChip("不关联", sel: selectedCourse.isEmpty) { selectedCourse = "" }
                ForEach(courses) { c in
                    courseChip(c.name, sel: selectedCourse == c.name) { selectedCourse = c.name }
                }
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
        }
    }

    private func courseChip(_ name: String, sel: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 12))
                .foregroundStyle(sel ? SonnetColors.ink : SonnetColors.textCaption)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(sel ? SonnetColors.inkWash : SonnetColors.paperCream))
                .overlay(Capsule().stroke(sel ? SonnetColors.inkMist : Color.clear, lineWidth: 1))
        }
    }

    // MARK: - Today Stats

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
            StudentSectionHeader(title: "今日摘要", subtitle: "把今天的专注节奏浓缩成三行")
            SonnetCard {
                HStack(spacing: 0) {
                    statCell(value: "\(todayCount) 次",         label: "今日专注")
                    statCell(value: fmtMinutes(todayMinutes),   label: "总时长")
                    statCell(value: "\(streakDays) 天\(streakDays >= 3 ? " 🔥" : "")",
                             label: "连续天数")
                }
                .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, SonnetDimens.spacingXL)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(SonnetColors.textTitle)
                .tracking(-0.5)
            Text(label)
                .font(SonnetTypography.caption2)
                .foregroundStyle(SonnetColors.textCaption)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SonnetDimens.spacingM)
    }

    private func fmtMinutes(_ m: Int) -> String {
        if m >= 60 {
            let h = m / 60; let r = m % 60
            return r > 0 ? "\(h)h \(r)m" : "\(h)h"
        }
        return "\(m)m"
    }

    // MARK: - Weekly Chart Section

    private var weeklyChartSection: some View {
        VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
            StudentSectionHeader(title: "本周专注", subtitle: "看看一周的节奏有没有慢慢稳定下来")
                .padding(.horizontal, SonnetDimens.spacingXL)

            FocusWeeklyChart(sessions: Array(sessions))
                .padding(.horizontal, SonnetDimens.spacingXL)
        }
    }

    // MARK: - Done Overlay

    private var doneOverlay: some View {
        ZStack {
            SonnetColors.paper.opacity(0.96).ignoresSafeArea()

            VStack(spacing: SonnetDimens.spacingXXL) {
                // 完整圆环 + ✓
                ZStack {
                    Circle()
                        .stroke(SonnetColors.jade.opacity(0.18), lineWidth: 6)
                        .frame(width: 200, height: 200)
                    Circle()
                        .trim(from: 0, to: 1.0)
                        .stroke(SonnetColors.jade,
                                style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 200, height: 200)

                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundStyle(SonnetColors.jade)
                        .scaleEffect(showDoneCheck ? 1 : 0)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.55),
                            value: showDoneCheck
                        )
                }

                VStack(spacing: SonnetDimens.spacingS) {
                    Text("太棒了！")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(SonnetColors.jade)
                    Text("本次专注 \(selectedMinutes) 分钟")
                        .font(SonnetTypography.body)
                        .foregroundStyle(SonnetColors.textSecond)
                }

                PoetryDivider()
                    .padding(.horizontal, SonnetDimens.spacingXXL)

                Button {
                    withAnimation(SonnetMotion.spring) { resetToIdle() }
                } label: {
                    Text("再来一次")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SonnetColors.ink)
                        .padding(.horizontal, SonnetDimens.spacingXXL)
                        .padding(.vertical, SonnetDimens.spacingM)
                        .background(Capsule().fill(SonnetColors.inkWash))
                }
            }
        }
    }

    // MARK: - Timer Logic

    private func start() {
        requestNotifPermission()
        let s = FocusSession(taskName: selectedCourse, duration: totalSeconds)
        modelContext.insert(s)
        try? modelContext.save()
        currentSession = s
        remaining      = totalSeconds
        phase          = .running
        quoteIndex     = 0
        HapticManager.impact(.medium)
        startTimer()
        scheduleNotif(after: remaining)
    }

    private func pause() {
        phase = .paused
        stopTimer()
        cancelNotif()
    }

    private func resume() {
        phase = .running
        startTimer()
        scheduleNotif(after: remaining)
    }

    private func abandon() {
        stopTimer(); cancelNotif()
        currentSession?.endTime     = Date()
        currentSession?.isCompleted = false
        try? modelContext.save()
        currentSession = nil
        withAnimation(SonnetMotion.spring) { phase = .idle }
        remaining = totalSeconds
    }

    private func complete() {
        stopTimer(); cancelNotif()
        currentSession?.endTime     = Date()
        currentSession?.isCompleted = true
        try? modelContext.save()
        currentSession = nil

        withAnimation(SonnetMotion.spring) { phase = .done }
        showDoneCheck = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                showDoneCheck = true
            }
        }
        HapticManager.success()
        if soundEnabled { AudioServicesPlayAlertSoundWithCompletion(1322, nil) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(SonnetMotion.spring) { resetToIdle() }
        }
    }

    private func resetToIdle() {
        phase         = .idle
        remaining     = totalSeconds
        showDoneCheck = false
        quoteIndex    = 0
    }

    private func startTimer() {
        timerRef = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if remaining > 0 { remaining -= 1 } else { complete() }
        }
    }

    private func stopTimer() {
        timerRef?.invalidate(); timerRef = nil
    }

    private func tickQuote(_ rem: Int) {
        let elapsed = totalSeconds - rem
        let idx = max(0, elapsed / 300)
        if idx != quoteIndex {
            withAnimation(SonnetMotion.springSlow) { quoteIndex = idx }
        }
    }

    // MARK: - Background / Scene

    private func handleScenePhase(_ p: ScenePhase) {
        switch p {
        case .background:
            if phase == .running { backgroundedAt = Date() }
        case .active:
            if let bg = backgroundedAt, phase == .running {
                let elapsed = Int(Date().timeIntervalSince(bg))
                remaining = max(0, remaining - elapsed)
                backgroundedAt = nil
                if remaining == 0 { complete() }
            }
        default: break
        }
    }

    // MARK: - Notifications

    private func requestNotifPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func scheduleNotif(after seconds: Int) {
        guard seconds > 0 else { return }
        let c = UNMutableNotificationContent()
        c.title = "专注完成！🎉"
        c.body  = "很棒，你完成了 \(selectedMinutes) 分钟专注"
        c.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let req = UNNotificationRequest(identifier: "sonnet.focus", content: c, trigger: trigger)
        UNUserNotificationCenter.current().add(req)
    }

    private func cancelNotif() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ["sonnet.focus"])
    }

    // MARK: - Helpers

    private func timeString(_ s: Int) -> String {
        String(format: "%02d:%02d", s / 60, s % 60)
    }
}

// MARK: - Weekly Chart

struct FocusWeeklyChart: View {
    let sessions: [FocusSession]

    private var bars: [(label: String, minutes: Int, isToday: Bool)] {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let dow   = cal.component(.weekday, from: today) // 1=Sun
        let fromMon = (dow + 5) % 7
        let labels  = ["一", "二", "三", "四", "五", "六", "日"]
        return (0..<7).map { i in
            let d    = cal.date(byAdding: .day, value: i - fromMon, to: today) ?? today
            let dEnd = cal.date(byAdding: .day, value: 1, to: d) ?? d
            let min  = sessions
                .filter { $0.startTime >= d && $0.startTime < dEnd && $0.isCompleted }
                .reduce(0) { $0 + $1.duration } / 60
            return (labels[i], min, cal.isDate(d, inSameDayAs: Date()))
        }
    }

    private var maxMin: Int { max(bars.map { $0.minutes }.max() ?? 0, 1) }

    var body: some View {
        SonnetCard {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(bars, id: \.label) { bar in
                    VStack(spacing: 3) {
                        if bar.minutes > 0 {
                            Text("\(bar.minutes)")
                                .font(.system(size: 9))
                                .foregroundStyle(SonnetColors.textHint)
                        }
                        RoundedRectangle(cornerRadius: 4)
                            .fill(bar.isToday ? SonnetColors.inkLight : SonnetColors.ink)
                            .frame(height: max(4, CGFloat(bar.minutes) / CGFloat(maxMin) * 52))
                        Text(bar.label)
                            .font(.system(size: 10))
                            .foregroundStyle(bar.isToday ? SonnetColors.ink : SonnetColors.textCaption)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            .padding(SonnetDimens.spacingM)
        }
        .animation(SonnetMotion.spring, value: bars.map { $0.minutes })
    }
}

#Preview {
    NavigationStack { FocusTimerView() }
        .modelContainer(for: [FocusSession.self, Course.self], inMemory: true)
}
