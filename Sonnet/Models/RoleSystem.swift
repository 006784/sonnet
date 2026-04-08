import Foundation

// MARK: - 用户角色

enum UserRole: String, Codable, CaseIterable {
    case student    = "student"
    case teacher    = "teacher"
    case freelancer = "freelancer"
    case family     = "family"
    case worker     = "worker"

    var displayName: String {
        switch self {
        case .student:    return "学生"
        case .teacher:    return "教师"
        case .freelancer: return "自由职业"
        case .family:     return "家庭"
        case .worker:     return "上班族"
        }
    }

    var icon: String {
        switch self {
        case .student:    return "graduationcap.fill"
        case .teacher:    return "person.bust"
        case .freelancer: return "laptopcomputer"
        case .family:     return "house.fill"
        case .worker:     return "briefcase.fill"
        }
    }

    var tagline: String {
        switch self {
        case .student:    return "用诗意记录校园时光"
        case .teacher:    return "用诗意记录教学岁月"
        case .freelancer: return "用诗意记录自由人生"
        case .family:     return "用诗意记录家庭温暖"
        case .worker:     return "用诗意记录奋斗足迹"
        }
    }

    /// 该角色专属的第二 Tab 图标
    var studyTabIcon: String {
        switch self {
        case .student:    return "book.fill"
        case .teacher:    return "person.text.rectangle.fill"
        case .freelancer: return "calendar.badge.clock"
        case .family:     return "figure.2.and.child.holdinghands"
        case .worker:     return "target"
        }
    }

    /// 该角色专属的第二 Tab 名称
    var studyTabLabel: String {
        switch self {
        case .student:    return "学习"
        case .teacher:    return "课程"
        case .freelancer: return "日程"
        case .family:     return "家庭"
        case .worker:     return "目标"
        }
    }
}
