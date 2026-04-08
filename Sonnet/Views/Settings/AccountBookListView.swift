import SwiftUI
import SwiftData

struct AccountBookListView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = SettingsViewModel()
    @State private var showingAdd = false
    @State private var newName = ""
    @State private var editingBook: AccountBook? = nil
    @State private var editName = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                SonnetCard {
                    VStack(spacing: 0) {
                        ForEach(Array(viewModel.accountBooks.enumerated()), id: \.element.id) { idx, book in
                            bookRow(book: book, isLast: idx == viewModel.accountBooks.count - 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
        }
        .background(SonnetColors.paper)
        .navigationTitle("账本管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
                        .foregroundStyle(SonnetColors.ink)
                }
            }
        }
        .alert("新建账本", isPresented: $showingAdd) {
            TextField("账本名称", text: $newName)
            Button("取消", role: .cancel) { newName = "" }
            Button("创建") {
                viewModel.newBookName = newName
                viewModel.addAccountBook(context: modelContext)
                syncSelectedBook()
                newName = ""
            }
        }
        .alert("重命名账本", isPresented: .init(
            get: { editingBook != nil },
            set: { if !$0 { editingBook = nil } }
        )) {
            TextField("账本名称", text: $editName)
            Button("取消", role: .cancel) { editingBook = nil }
            Button("保存") {
                editingBook?.name = editName
                try? modelContext.save()
                editingBook = nil
                reloadBooks()
            }
        }
        .onAppear { reloadBooks() }
    }

    @ViewBuilder
    private func bookRow(book: AccountBook, isLast: Bool) -> some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(book.isSelected ? SonnetColors.inkWash : SonnetColors.paperCream)
                    .frame(width: 36, height: 36)
                Image(systemName: book.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(book.isSelected ? SonnetColors.ink : SonnetColors.textCaption)
            }

            // Name + budget
            VStack(alignment: .leading, spacing: 2) {
                Text(book.name)
                    .font(SonnetTypography.body)
                    .foregroundStyle(SonnetColors.textTitle)
                if book.budget > 0 {
                    Text("月预算 ¥\(CurrencyUtils.format(book.budget))")
                        .font(SonnetTypography.caption2)
                        .foregroundStyle(SonnetColors.textCaption)
                }
            }

            Spacer()

            if book.isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(SonnetColors.ink)
            }
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(SonnetMotion.spring) {
                viewModel.selectBook(book, context: modelContext)
                syncSelectedBook()
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Delete (only if more than one book)
            if viewModel.accountBooks.count > 1 {
                Button(role: .destructive) {
                    withAnimation {
                        viewModel.deleteBook(book, context: modelContext)
                        syncSelectedBook()
                    }
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }

            // Rename
            Button {
                editName = book.name
                editingBook = book
            } label: {
                Label("重命名", systemImage: "pencil")
            }
            .tint(SonnetColors.inkLight)
        }

        if !isLast {
            Rectangle()
                .fill(SonnetColors.paperLine)
                .frame(height: 0.5)
                .padding(.leading, 68)
        }
    }

    private func reloadBooks() {
        viewModel.loadAccountBooks(context: modelContext)
        syncSelectedBook()
    }

    private func syncSelectedBook() {
        appState.syncCurrentBook(viewModel.accountBooks.first(where: { $0.isSelected }))
    }
}

// MARK: – Preview

#Preview {
    NavigationStack {
        AccountBookListView()
    }
    .modelContainer(for: [AccountBook.self, Record.self, Category.self], inMemory: true)
}
