import SwiftUI
import SwiftData

@Observable
final class SettingsViewModel {
    var accountBooks: [AccountBook] = []
    var showingAddBook: Bool = false
    var showingBudgetSheet: Bool = false
    var selectedBook: AccountBook?
    var newBookName: String = ""
    var aiApiKey: String = ""

    func loadAccountBooks(context: ModelContext) {
        let desc = FetchDescriptor<AccountBook>(sortBy: [SortDescriptor(\.createdAt)])
        accountBooks = (try? context.fetch(desc)) ?? []
    }

    func addAccountBook(context: ModelContext) {
        let trimmedName = newBookName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let isFirstBook = accountBooks.isEmpty
        let book = AccountBook(name: trimmedName, isSelected: isFirstBook)
        context.insert(book)
        try? context.save()
        newBookName = ""
        loadAccountBooks(context: context)
    }

    func selectBook(_ book: AccountBook, context: ModelContext) {
        accountBooks.forEach { $0.isSelected = false }
        book.isSelected = true
        try? context.save()
        loadAccountBooks(context: context)
    }

    func deleteBook(_ book: AccountBook, context: ModelContext) {
        let deletedSelectedBook = book.isSelected
        context.delete(book)

        if deletedSelectedBook {
            let descriptor = FetchDescriptor<AccountBook>(sortBy: [SortDescriptor(\.createdAt)])
            if let nextBook = (try? context.fetch(descriptor))?.first(where: { $0.id != book.id }) {
                nextBook.isSelected = true
            }
        }

        try? context.save()
        loadAccountBooks(context: context)
    }
}
