import SwiftUI
import SwiftData

@Observable
final class RecordViewModel {
    var amountInput: String = "0"
    var selectedType: RecordType = .expense
    var selectedCategory: Category?
    var note: String = ""
    var date: Date = Date()
    var isSaving: Bool = false
    var saveSuccess: Bool = false
    var editingRecord: Record?

    var amount: Double { Double(amountInput) ?? 0 }
    var canSave: Bool { amount > 0 && selectedCategory != nil }

    func appendDigit(_ digit: String) {
        if amountInput == "0" && digit != "." {
            amountInput = digit
        } else if digit == "." && amountInput.contains(".") {
            return
        } else if let dotIdx = amountInput.firstIndex(of: "."),
                  amountInput.distance(from: dotIdx, to: amountInput.endIndex) > 2 {
            return
        } else {
            amountInput += digit
        }
    }

    func deleteDigit() {
        guard amountInput.count > 1 else { amountInput = "0"; return }
        amountInput.removeLast()
    }

    @discardableResult
    func save(context: ModelContext, accountBook: AccountBook?) -> Bool {
        guard canSave, let category = selectedCategory, let book = accountBook else { return false }
        isSaving = true

        let targetRecord: Record
        if let editingRecord {
            targetRecord = editingRecord
        } else {
            targetRecord = Record(
                amount: amount,
                categoryId: category.id,
                note: note,
                date: date,
                type: selectedType.rawValue,
                accountBookId: book.id
            )
            context.insert(targetRecord)
        }

        targetRecord.amount = amount
        targetRecord.categoryId = category.id
        targetRecord.note = note
        targetRecord.date = date
        targetRecord.type = selectedType.rawValue
        targetRecord.accountBookId = book.id
        targetRecord.category = category
        targetRecord.accountBook = book

        do {
            try context.save()
            saveSuccess = true
            isSaving = false
            return true
        } catch {
            saveSuccess = false
            isSaving = false
            return false
        }
    }

    func reset() {
        amountInput = "0"
        note = ""
        date = Date()
        selectedCategory = nil
        saveSuccess = false
        editingRecord = nil
    }

    func loadForEditing(_ record: Record) {
        editingRecord = record
        let value = record.amount
        amountInput = value.rounded(.towardZero) == value ? String(Int(value)) : String(value)
        selectedType = RecordType(rawValue: record.type) ?? .expense
        selectedCategory = record.category
        note = record.note
        date = record.date
    }

    func loadDraft(_ draft: QuickRecordDraft, context: ModelContext) {
        editingRecord = nil

        let normalizedAmount = max(draft.amount, 0)
        amountInput = normalizedAmount.rounded(.towardZero) == normalizedAmount
            ? String(Int(normalizedAmount))
            : String(normalizedAmount)
        selectedType = RecordType(rawValue: draft.type) ?? .expense
        note = draft.note
        date = Date()

        let targetType = selectedType.rawValue
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { $0.type == targetType },
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let categories = (try? context.fetch(descriptor)) ?? []

        if !draft.categoryName.isEmpty {
            selectedCategory = categories.first(where: { $0.name == draft.categoryName })
        }
        selectedCategory = selectedCategory ?? categories.first
    }
}
