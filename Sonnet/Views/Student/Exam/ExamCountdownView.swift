import SwiftUI
import SwiftData

struct ExamCountdownView: View {
    @Query(sort: [SortDescriptor(\Exam.date)])
    private var exams: [Exam]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var editingExam: Exam? = nil
    @State private var now = Date()
    @State private var showPast = false

    private var upcoming: [Exam] {
        exams.filter { !$0.isCompleted && $0.date >= now }
    }
    private var past: [Exam] {
        exams.filter { $0.isCompleted || $0.date < now }
    }

    private var nearTermCount: Int {
        upcoming.filter { exam in
            (Calendar.current.dateComponents([.day], from: now, to: exam.date).day ?? 8) <= 7
        }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: SonnetDimens.spacingL) {
                summaryCard

                if upcoming.isEmpty && past.isEmpty {
                    EmptyStateView(title: "暂无考试安排", subtitle: "提前规划，从容备考")
                        .padding(.top, 40)
                }

                if !upcoming.isEmpty {
                    VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                        StudentSectionHeader(title: "即将到来", subtitle: "优先处理最近几场考试")
                        ForEach(upcoming) { exam in
                            examCard(exam)
                        }
                    }
                }

                if !past.isEmpty {
                    VStack(alignment: .leading, spacing: SonnetDimens.spacingM) {
                        Button {
                            withAnimation(SonnetMotion.spring) { showPast.toggle() }
                        } label: {
                            HStack {
                                StudentSectionHeader(title: "已结束", subtitle: "共 \(past.count) 条历史记录")
                                Spacer()
                                Image(systemName: showPast ? "chevron.up" : "chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundStyle(SonnetColors.textHint)
                            }
                        }
                        .buttonStyle(.plain)

                        if showPast {
                            ForEach(past) { exam in
                                examCard(exam, dimmed: true)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
            .padding(.top, SonnetDimens.spacingL)
            .padding(.bottom, 40)
        }
        .background(SonnetColors.paper)
        .navigationTitle("考试倒计时")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .sheet(isPresented: $showingAdd) { ExamEditSheet() }
        .sheet(item: $editingExam) { ExamEditSheet(editing: $0) }
        .onAppear { now = Date() }
    }

    private var summaryCard: some View {
        StudentHeroCard(
            title: "考试倒计时",
            subtitle: "把最近的考试放在眼前，给复习预留出更从容的节奏。",
            icon: "calendar.badge.clock",
            colorName: "gift"
        ) {
            HStack(spacing: SonnetDimens.spacingM) {
                StudentMetricPill(title: "未完成", value: "\(upcoming.count)", tint: SonnetColors.ink)
                StudentMetricPill(title: "近 7 天", value: "\(nearTermCount)", tint: SonnetColors.amber)
                StudentMetricPill(title: "已结束", value: "\(past.count)", tint: SonnetColors.textCaption)
            }
        }
    }

    // MARK: - 考试卡片

    @ViewBuilder
    private func examCard(_ exam: Exam, dimmed: Bool = false) -> some View {
        let days = Calendar.current.dateComponents([.day], from: now, to: exam.date).day ?? 0
        let isUrgent = !dimmed && days <= 3
        let isWarning = !dimmed && days <= 7 && days > 3

        SonnetCard {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(dimmed ? SonnetColors.textHint
                          : isUrgent ? SonnetColors.vermilion
                          : isWarning ? SonnetColors.amber
                          : SonnetColors.jade)
                    .frame(width: 4)

                VStack(spacing: 1) {
                    if dimmed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(SonnetColors.textHint)
                    } else {
                        Text("\(max(0, days))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(isUrgent ? SonnetColors.vermilion
                                             : isWarning ? SonnetColors.amber
                                             : SonnetColors.jade)
                            .contentTransition(.numericText())
                            .overlay(alignment: .topTrailing) {
                                if isUrgent {
                                    PulsingDot()
                                        .offset(x: 4, y: -4)
                                }
                            }
                        Text("天")
                            .font(.system(size: 11))
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                }
                .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exam.name.isEmpty ? exam.courseName : exam.name)
                        .font(SonnetTypography.bodyBold)
                        .foregroundStyle(dimmed ? SonnetColors.textHint : SonnetColors.textTitle)
                    if !exam.courseName.isEmpty && !exam.name.isEmpty {
                        Text(exam.courseName)
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                    HStack(spacing: 6) {
                        Text(DateUtils.dayString(exam.date))
                            .font(SonnetTypography.caption2)
                            .foregroundStyle(SonnetColors.textHint)
                        if !exam.location.isEmpty {
                            Text("· \(exam.location)")
                                .font(SonnetTypography.caption2)
                                .foregroundStyle(SonnetColors.textHint)
                        }
                    }
                }

                Spacer()

                Menu {
                    Button {
                        exam.isCompleted.toggle()
                        try? modelContext.save()
                    } label: {
                        Label(dimmed ? "恢复为未完成" : "标记完成", systemImage: dimmed ? "arrow.uturn.backward" : "checkmark")
                    }

                    Button(role: .destructive) {
                        modelContext.delete(exam)
                        try? modelContext.save()
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(SonnetColors.textHint)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .opacity(dimmed ? 0.6 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                editingExam = exam
            }
        }
    }
}

// MARK: - 脉冲动画小圆点

struct PulsingDot: View {
    @State private var pulsing = false

    var body: some View {
        ZStack {
            Circle()
                .fill(SonnetColors.vermilion.opacity(0.3))
                .frame(width: 12, height: 12)
                .scaleEffect(pulsing ? 1.8 : 1)
                .opacity(pulsing ? 0 : 1)
            Circle()
                .fill(SonnetColors.vermilion)
                .frame(width: 7, height: 7)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                pulsing = true
            }
        }
    }
}

#Preview {
    NavigationStack { ExamCountdownView() }
        .modelContainer(for: Exam.self, inMemory: true)
}
