import SwiftUI
import SwiftData

struct GPACalculatorView: View {
    @Query(sort: [SortDescriptor(\GPARecord.createdAt, order: .reverse)])
    private var records: [GPARecord]
    @Environment(\.modelContext) private var modelContext

    @State private var showingAdd = false
    @State private var semesterFilter = "全部"
    @State private var targetGPA: Double = 3.5
    @State private var showTargetCalc = false

    private var semesters: [String] {
        let all = Array(Set(records.map { $0.semester })).sorted()
        return ["全部"] + all
    }

    private var filtered: [GPARecord] {
        semesterFilter == "全部"
            ? records
            : records.filter { $0.semester == semesterFilter }
    }

    private var gpa: Double {
        let totalCredits = filtered.reduce(0) { $0 + $1.credit }
        guard totalCredits > 0 else { return 0 }
        return filtered.reduce(0) { $0 + $1.gradePoint * $1.credit } / totalCredits
    }

    private var totalCredits: Double {
        filtered.reduce(0) { $0 + $1.credit }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SonnetDimens.spacingL) {

                // ── GPA 环形图 ──────────────────────────────────
                gpaRingCard

                // ── 学期筛选 ────────────────────────────────────
                if semesters.count > 2 {
                    StudentSectionHeader(title: "学期筛选", subtitle: "按学期阅读成绩变化")
                        .padding(.horizontal, SonnetDimens.spacingXL)
                    semesterPicker
                }

                // ── 目标 GPA 计算器 ─────────────────────────────
                StudentSectionHeader(title: "目标 GPA", subtitle: "估算后续课程需要达到的节奏")
                    .padding(.horizontal, SonnetDimens.spacingXL)
                targetCalculatorSection

                // ── 成绩列表 ────────────────────────────────────
                if filtered.isEmpty {
                    EmptyStateView(title: "还没有成绩", subtitle: "点击右上角添加第一条成绩")
                        .padding(.top, 40)
                } else {
                    StudentSectionHeader(title: "成绩记录", subtitle: "按当前筛选展示 \(filtered.count) 门课程")
                        .padding(.horizontal, SonnetDimens.spacingXL)
                    gradeList
                }

                Spacer(minLength: 40)
            }
            .padding(.top, SonnetDimens.spacingL)
        }
        .background(SonnetColors.paper)
        .navigationTitle("GPA 计算")
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
        .sheet(isPresented: $showingAdd) { AddGPARecordSheet() }
    }

    // MARK: - GPA 环形卡

    private var gpaRingCard: some View {
        StudentHeroCard(
            title: "GPA 概览",
            subtitle: "把绩点、均分和总学分收进同一页，读起来会更安静也更清楚。",
            icon: "chart.line.uptrend.xyaxis",
            colorName: "parttime"
        ) {
            HStack(spacing: SonnetDimens.spacingXL) {
                // 环形图
                ZStack {
                    Circle()
                        .stroke(SonnetColors.inkWash, lineWidth: 12)
                        .frame(width: 120, height: 120)
                    Circle()
                        .trim(from: 0, to: min(gpa / 4.0, 1))
                        .stroke(
                            gpaColor(gpa),
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(SonnetMotion.spring, value: gpa)
                    VStack(spacing: 2) {
                        Text(String(format: "%.2f", gpa))
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundStyle(gpaColor(gpa))
                            .contentTransition(.numericText())
                        Text("GPA")
                            .font(.system(size: 12))
                            .foregroundStyle(SonnetColors.textCaption)
                    }
                }

                // 统计数据
                VStack(alignment: .leading, spacing: 10) {
                    statRow(label: "总学分", value: String(format: "%.1f", totalCredits))
                    statRow(label: "门数", value: "\(filtered.count)")
                    statRow(label: "平均分",
                            value: filtered.isEmpty ? "--" : String(format: "%.1f",
                                   filtered.reduce(0) { $0 + $1.score } / Double(filtered.count)))
                }
            }
        }
        .padding(.horizontal, SonnetDimens.spacingXL)
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(SonnetTypography.caption1)
                .foregroundStyle(SonnetColors.textCaption)
            Spacer()
            Text(value)
                .font(SonnetTypography.bodyBold)
                .foregroundStyle(SonnetColors.textTitle)
        }
    }

    // MARK: - 学期筛选

    private var semesterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(semesters, id: \.self) { sem in
                    let isSelected = sem == semesterFilter
                    Button {
                        withAnimation(SonnetMotion.spring) { semesterFilter = sem }
                    } label: {
                        Text(sem)
                            .font(SonnetTypography.caption1)
                            .foregroundStyle(isSelected ? .white : SonnetColors.textCaption)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(isSelected ? SonnetColors.ink : SonnetColors.paperCream)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, SonnetDimens.spacingXL)
        }
    }

    // MARK: - 目标 GPA 计算器

    private var targetCalculatorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(SonnetMotion.spring) { showTargetCalc.toggle() }
            } label: {
                HStack {
                    Label("目标 GPA 计算器", systemImage: "target")
                        .font(SonnetTypography.caption1)
                        .foregroundStyle(SonnetColors.textCaption)
                    Spacer()
                    Image(systemName: showTargetCalc ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12))
                        .foregroundStyle(SonnetColors.textHint)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SonnetDimens.spacingXL)

            if showTargetCalc {
                SonnetCard {
                    VStack(spacing: 12) {
                        HStack {
                            Text("目标 GPA")
                                .font(SonnetTypography.body)
                                .foregroundStyle(SonnetColors.textBody)
                            Spacer()
                            Text(String(format: "%.1f", targetGPA))
                                .font(SonnetTypography.bodyBold)
                                .foregroundStyle(SonnetColors.ink)
                        }
                        Slider(value: $targetGPA, in: 1.0...4.0, step: 0.1)
                            .tint(SonnetColors.ink)

                        Divider()

                        targetAdviceRow
                    }
                    .padding(SonnetDimens.spacingL)
                }
                .padding(.horizontal, SonnetDimens.spacingXL)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var targetAdviceRow: some View {
        let diff = targetGPA - gpa
        let advice: String
        if filtered.isEmpty {
            advice = "先添加成绩，再计算目标"
        } else if diff <= 0 {
            advice = "你已达到目标！继续保持 \u{1F389}"
        } else {
            let needed = String(format: "%.2f", min(4.0, gpa + diff * 1.5))
            advice = "后续课程平均绩点需达 \(needed) 才能完成目标"
        }
        return Text(advice)
            .font(SonnetTypography.caption1)
            .foregroundStyle(diff <= 0 ? SonnetColors.jade : SonnetColors.amber)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 成绩列表

    private var gradeList: some View {
        SonnetCard {
            VStack(spacing: 0) {
                ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, rec in
                    gradeRow(rec)
                    if idx < filtered.count - 1 {
                        Divider().padding(.leading, 18)
                    }
                }
            }
        }
        .padding(.horizontal, SonnetDimens.spacingXL)
    }

    private func gradeRow(_ rec: GPARecord) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(rec.courseName)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textBody)
                Text("\(rec.semester.isEmpty ? "未设学期" : rec.semester) · \(String(format: "%.1f", rec.credit)) 学分")
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(SonnetColors.textHint)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(String(format: "%.0f", rec.score))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(SonnetColors.textTitle)
                Text(String(format: "GP %.1f", rec.gradePoint))
                    .font(SonnetTypography.caption2)
                    .foregroundStyle(gpaColor(rec.gradePoint))
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 60)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                modelContext.delete(rec); try? modelContext.save()
            } label: { Label("删除", systemImage: "trash") }
        }
    }

    // MARK: - 工具

    private func gpaColor(_ value: Double) -> Color {
        value >= 3.7 ? SonnetColors.jade
            : value >= 2.0 ? SonnetColors.amber
            : SonnetColors.vermilion
    }
}

// MARK: - 添加成绩 Sheet

struct AddGPARecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var courseName = ""
    @State private var score: Double = 85
    @State private var credit: Double = 2
    @State private var semester = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("科目名称", text: $courseName)
                    TextField("学期（如 2024春）", text: $semester)
                }
                Section("成绩") {
                    HStack {
                        Text("百分制成绩")
                        Spacer()
                        Text(String(format: "%.0f", score))
                            .foregroundStyle(SonnetColors.ink)
                            .fontWeight(.semibold)
                    }
                    Slider(value: $score, in: 0...100, step: 1)
                        .tint(SonnetColors.ink)
                }
                Section("学分") {
                    Stepper("\(String(format: "%.1f", credit)) 学分",
                            value: $credit, in: 0.5...10, step: 0.5)
                }
                Section("自动换算") {
                    HStack {
                        Text("绩点（4.0）")
                        Spacer()
                        Text(String(format: "%.1f", GradeRecord.scoreToGradePoint(score)))
                            .foregroundStyle(SonnetColors.jade)
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("添加成绩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let rec = GPARecord(courseName: courseName, credit: credit,
                                            score: score, semester: semester)
                        modelContext.insert(rec)
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(courseName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack { GPACalculatorView() }
        .modelContainer(for: GPARecord.self, inMemory: true)
}
