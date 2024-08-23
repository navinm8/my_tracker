import SwiftUI
import CoreData

enum GroupBy: String, CaseIterable {
    case day = "Day"
    case category = "Category"
    case day_sorted = "Day - Sorted"
}

struct DashboardView: View {
    @State private var selectedMonth = Calendar.current.component(.month, from: Date()) - 1
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var currentPage = 1
    @State private var itemsPerPage = 10
    @State private var showingEditSheet = false
    @State private var editingExpenditure: Expenditure?
    @State private var selectedGroupBy: GroupBy = .day
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest var expenditures: FetchedResults<Expenditure>

    private let dateFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter
    }()

    init(selectedDate: Date? = nil) {
        let calendar = Calendar.current
        let date = selectedDate ?? Date()
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        _selectedMonth = State(initialValue: month - 1)  // Adjusting for 0-based index
        _selectedYear = State(initialValue: year)
        
        _expenditures = FetchRequest(
            entity: Expenditure.entity(),
            sortDescriptors: [NSSortDescriptor(keyPath: \Expenditure.date, ascending: false)],
            predicate: NSPredicate(format: "TRUEPREDICATE")
        )
    }

    var body: some View {
        VStack(spacing: 16) {
            filterSection
            totalSpentView
            expenditureListView
        }
        .navigationTitle("Monthly Expenditure")
        .onAppear {
            updateFetchRequest()
        }
        .sheet(isPresented: $showingEditSheet) {
            if let expenditure = editingExpenditure {
                AddExpenditureView(isPresented: $showingEditSheet, expenditureToEdit: expenditure)
            }
        }
    }

    private var filterSection: some View {
        HStack {
            monthPicker
            yearPicker
            Spacer()
            groupByPicker
        }
        .padding(.horizontal)
    }

    private var monthPicker: some View {
        Picker("Month", selection: $selectedMonth) {
            ForEach(0..<12, id: \.self) { month in
                Text(Calendar.current.monthSymbols[month].prefix(3))
                    .tag(month)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: selectedMonth) { _ in updateFetchRequest() }
    }

    private var yearPicker: some View {
        Picker("Year", selection: $selectedYear) {
            ForEach((selectedYear-5)...(selectedYear+5), id: \.self) { year in
                Text(String(year))
                    .tag(year)
            }
        }
        .pickerStyle(MenuPickerStyle())
        .onChange(of: selectedYear) { _ in updateFetchRequest() }
    }

    private var groupByPicker: some View {
        Picker("Group", selection: $selectedGroupBy) {
            ForEach(GroupBy.allCases, id: \.self) { groupBy in
                Text(groupBy.rawValue).tag(groupBy)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var totalSpentView: some View {
        Text("Total spent: ₹\(totalAmountSpent, specifier: "%.2f")")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.bottom, 5)
    }

    private var expenditureListView: some View {
        List {
            ForEach(groupedExpenditures, id: \.id) { group in
                expenditureSection(for: group)
            }
        }
    }

    private func expenditureSection(for group: GroupedExpenditures) -> some View {
        Section(header: groupHeader(for: group)) {
            ForEach(group.items) { expenditure in
                ExpenditureRow(expenditure: expenditure)
                    .if(selectedGroupBy == .day) { view in
                        view
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    deleteExpenditure(expenditure)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editingExpenditure = expenditure
                                    showingEditSheet = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
            }
        }
    }

    private func groupHeader(for group: GroupedExpenditures) -> some View {
        HStack {
            Text(group.title)
            Spacer()
            Text("Total: ₹\(group.totalAmount, specifier: "%.2f")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var totalAmountSpent: Double {
        expenditures.reduce(0) { $0 + $1.amount }
    }

    private var groupedExpenditures: [GroupedExpenditures] {
        switch selectedGroupBy {
        case .day:
            return groupByDayWithoutSorting()
        case .category:
            return groupByCategoryWithSorting()
        case .day_sorted:
            return groupByDayWithSorting()
        }
    }

    private func groupByDayWithoutSorting() -> [GroupedExpenditures] {
        let grouped = Dictionary(grouping: paginatedExpenditures) { expenditure in
            Calendar.current.startOfDay(for: expenditure.date ?? Date())
        }
        return grouped.map { date, items in
            GroupedExpenditures(title: dateFormatter.string(from: date), items: items)
        }.sorted { group1, group2 in
            // Sort by date to maintain chronological order
            guard let date1 = dateFormatter.date(from: group1.title),
                  let date2 = dateFormatter.date(from: group2.title) else {
                return false
            }
            return date1 > date2 // Most recent dates first
        }
    }

    private func groupByCategoryWithSorting() -> [GroupedExpenditures] {
        let grouped = Dictionary(grouping: expenditures, by: { $0.category ?? "Unknown" })
        return grouped.map { category, items in
            GroupedExpenditures(title: category, items: items)
        }.sorted { $0.totalAmount > $1.totalAmount } // Sort by totalAmount in descending order
    }

    private func groupByDayWithSorting() -> [GroupedExpenditures] {
        let grouped = Dictionary(grouping: expenditures) { expenditure in
            Calendar.current.startOfDay(for: expenditure.date ?? Date())
        }
        return grouped.map { date, items in
            GroupedExpenditures(title: dateFormatter.string(from: date), items: items)
        }.sorted { group1, group2 in
            if group1.totalAmount != group2.totalAmount {
                return group1.totalAmount > group2.totalAmount // Primary sort by amount descending
            } else {
                return group1.title > group2.title // Secondary sort by date descending
            }
        }
    }

    private var paginatedExpenditures: [Expenditure] {
        let startIndex = (currentPage - 1) * itemsPerPage
        return Array(expenditures[startIndex..<min(startIndex + itemsPerPage, expenditures.count)])
    }

    private var totalPages: Int {
        Int(ceil(Double(expenditures.count) / Double(itemsPerPage)))
    }

    private func updateFetchRequest() {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: selectedYear, month: selectedMonth + 1))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        
        expenditures.nsPredicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfMonth as NSDate, endOfMonth as NSDate)
        currentPage = 1
    }

    private func deleteExpenditure(_ expenditure: Expenditure) {
        viewContext.delete(expenditure)
        do {
            try viewContext.save()
        } catch {
            print("Error deleting expenditure: \(error)")
        }
    }
}

struct GroupedExpenditures: Identifiable {
    let id = UUID()
    let title: String
    let items: [Expenditure]
    let totalAmount: Double

    init(title: String, items: [Expenditure]) {
        self.title = title
        self.items = items
        self.totalAmount = items.reduce(0) { $0 + $1.amount }
    }
}

struct ExpenditureRow: View {
    let expenditure: Expenditure
    
    var body: some View {
        HStack(alignment: .top) {
            DateCircle(date: expenditure.date ?? Date())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(expenditure.category ?? "Unknown")
                    .font(.headline)
                if let comment = expenditure.comment, !comment.isEmpty {
                    Text(truncateComment(comment))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()

            Text("₹\(expenditure.amount, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func truncateComment(_ comment: String) -> String {
        let maxLength = 30
        if comment.count <= maxLength {
            return comment
        } else {
            return String(comment.prefix(maxLength - 3)) + "..."
        }
    }
}

struct DateCircle: View {
    let date: Date
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
                .frame(width: 40, height: 40)
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

struct EditExpenditureView: View {
    @ObservedObject var expenditure: Expenditure
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var category: String
    @State private var date: Date
    @State private var amount: Double
    
    init(expenditure: Expenditure, isPresented: Binding<Bool>) {
        self.expenditure = expenditure
        self._isPresented = isPresented
        _category = State(initialValue: expenditure.category ?? "")
        _date = State(initialValue: expenditure.date ?? Date())
        _amount = State(initialValue: expenditure.amount)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Category", text: $category)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Amount", value: $amount, format: .currency(code: "INR"))
                    .keyboardType(.decimalPad)
            }
            .navigationTitle("Edit Expenditure")
            .navigationBarItems(
                leading: Button("Cancel") { isPresented = false },
                trailing: Button("Save") { saveChanges() }
            )
        }
    }
    
    private func saveChanges() {
        expenditure.category = category
        expenditure.date = date
        expenditure.amount = amount
        
        do {
            try viewContext.save()
            isPresented = false
        } catch {
            print("Error saving changes: \(error)")
        }
    }
}

struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

extension View {
    @ViewBuilder func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
