import SwiftData
import Foundation

// MARK: - 课程（课表）

@Model
final class Course {
    var id: UUID = UUID()
    var name: String = ""
    var teacher: String = ""
    var location: String = ""
    var weekday: Int = 1           // 1=周一 … 7=周日
    var startPeriod: Int = 1       // 起始节次
    var endPeriod: Int = 2         // 结束节次
    var colorName: String = "ink"  // 8色系之一
    var semester: String = ""      // e.g. "2024春"
    var startWeek: Int = 1         // 起始周
    var endWeek: Int = 16          // 结束周
    var note: String = ""
    var createdAt: Date = Date()

    init(name: String, teacher: String = "", location: String = "",
         weekday: Int, startPeriod: Int, endPeriod: Int,
         colorName: String = "ink", semester: String = "",
         startWeek: Int = 1, endWeek: Int = 16) {
        self.name        = name
        self.teacher     = teacher
        self.location    = location
        self.weekday     = weekday
        self.startPeriod = startPeriod
        self.endPeriod   = endPeriod
        self.colorName   = colorName
        self.semester    = semester
        self.startWeek   = startWeek
        self.endWeek     = endWeek
    }
}

// MARK: - 待办事项

@Model
final class TodoItem {
    var id: UUID = UUID()
    var title: String = ""
    var note: String = ""
    var dueDate: Date? = nil
    var isCompleted: Bool = false
    var priority: Int = 1          // 0=低 1=中 2=高
    var tag: String = "学习"       // "学习" / "生活" / "其他"
    var createdAt: Date = Date()
    var completedAt: Date? = nil

    init(title: String, note: String = "", dueDate: Date? = nil,
         priority: Int = 1, tag: String = "学习") {
        self.title    = title
        self.note     = note
        self.dueDate  = dueDate
        self.priority = priority
        self.tag      = tag
    }
}

// MARK: - 专注记录（番茄钟）

@Model
final class FocusSession {
    var id: UUID = UUID()
    var taskName: String = ""
    var duration: Int = 1500       // 秒，默认 25 分钟
    var startTime: Date = Date()
    var endTime: Date? = nil
    var isCompleted: Bool = false

    init(taskName: String, duration: Int = 1500) {
        self.taskName = taskName
        self.duration = duration
    }
}

// MARK: - 课堂笔记 v2（支持图片 / AI 摘要 / 颜色）

@Model
final class Note {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""        // Markdown 格式
    var courseName: String = ""
    var colorName: String = "ink"   // 颜色标识
    var imageData: [Data] = []      // 拍照插入的图片（已压缩 JPEG）
    var aiSummary: String? = nil    // AI 生成的摘要
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String, content: String = "", courseName: String = "",
         colorName: String = "ink", isPinned: Bool = false) {
        self.title      = title
        self.content    = content
        self.courseName = courseName
        self.colorName  = colorName
        self.isPinned   = isPinned
    }
}

// MARK: - 学习资料

@Model
final class StudyFile {
    var id: UUID = UUID()
    var name: String = ""
    var fileType: String = ""       // "pdf" / "image" / "doc"
    var courseName: String = ""
    var fileData: Data? = nil       // 小文件（< 5 MB）直接存
    var fileURL: String = ""        // 大文件存 App Documents 目录
    var fileSize: Int = 0           // bytes
    var createdAt: Date = Date()

    init(name: String, fileType: String, courseName: String = "") {
        self.name       = name
        self.fileType   = fileType
        self.courseName = courseName
    }
}

// MARK: - 课堂笔记 v1（旧，保留 Schema 兼容）

@Model
final class StudyNote {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var courseName: String = ""
    var tags: [String] = []
    var isPinned: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(title: String, content: String = "", courseName: String = "", tags: [String] = []) {
        self.title      = title
        self.content    = content
        self.courseName = courseName
        self.tags       = tags
    }
}

// MARK: - 考试

@Model
final class Exam {
    var id: UUID = UUID()
    var name: String = ""          // 考试名称（如 "期末考试"）
    var courseName: String = ""    // 科目名称
    var date: Date = Date()        // 考试日期
    var location: String = ""
    var note: String = ""
    var isCompleted: Bool = false
    var createdAt: Date = Date()

    init(name: String = "", courseName: String, date: Date,
         location: String = "", note: String = "") {
        self.name       = name
        self.courseName = courseName
        self.date       = date
        self.location   = location
        self.note       = note
    }
}

// MARK: - 成绩记录（原始 GradeRecord，保留兼容）

@Model
final class GradeRecord {
    var id: UUID = UUID()
    var subject: String = ""
    var score: Double = 0          // 百分制成绩
    var credit: Double = 2         // 学分
    var semester: String = ""
    var gradePoint: Double = 0     // 绩点（4.0 制）
    var createdAt: Date = Date()

    init(subject: String, score: Double, credit: Double = 2, semester: String = "") {
        self.subject    = subject
        self.score      = score
        self.credit     = credit
        self.semester   = semester
        self.gradePoint = GradeRecord.scoreToGradePoint(score)
    }

    // 百分制 → 4.0 绩点（国内常用换算）
    static func scoreToGradePoint(_ score: Double) -> Double {
        switch score {
        case 95...100: return 4.0
        case 90..<95:  return 3.7
        case 85..<90:  return 3.3
        case 82..<85:  return 3.0
        case 78..<82:  return 2.7
        case 75..<78:  return 2.3
        case 72..<75:  return 2.0
        case 68..<72:  return 1.7
        case 64..<68:  return 1.3
        case 60..<64:  return 1.0
        default:       return 0.0
        }
    }
}

// MARK: - GPA 成绩（GPA 计算器专用）

@Model
final class GPARecord {
    var id: UUID = UUID()
    var courseName: String = ""
    var credit: Double = 2.0
    var score: Double = 0.0        // 百分制
    var gradePoint: Double = 0.0   // 4.0 制绩点
    var semester: String = ""
    var createdAt: Date = Date()

    init(courseName: String, credit: Double = 2.0, score: Double, semester: String = "") {
        self.courseName  = courseName
        self.credit      = credit
        self.score       = score
        self.semester    = semester
        self.gradePoint  = GradeRecord.scoreToGradePoint(score)
    }
}
