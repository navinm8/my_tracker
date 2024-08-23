import SwiftUI

struct AddExpenditureView: View {
    @Binding var isPresented: Bool
    @State private var amountSpent: String = ""
    @State private var category: Categories = .groceries
    @State private var paymentMode: PaymentMode = .cash
    @State private var spentBy: SpentBy = .navin
    @State private var date: Date = Date()
    @State private var comment: String = ""
    @Environment(\.managedObjectContext) private var viewContext
    
    var expenditureToEdit: Expenditure?
    
    init(isPresented: Binding<Bool>, expenditureToEdit: Expenditure? = nil) {
        self._isPresented = isPresented
        self.expenditureToEdit = expenditureToEdit
        
        if let expenditure = expenditureToEdit {
            _amountSpent = State(initialValue: String(format: "%.2f", expenditure.amount))
            _category = State(initialValue: Categories(rawValue: expenditure.category ?? "") ?? .groceries)
            _paymentMode = State(initialValue: PaymentMode(rawValue: expenditure.paymentMode ?? "") ?? .cash)
            _spentBy = State(initialValue: SpentBy(rawValue: expenditure.spentBy ?? "") ?? .navin)
            _date = State(initialValue: expenditure.date ?? Date())
            _comment = State(initialValue: expenditure.comment ?? "")
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Amount spent : ₹", text: $amountSpent)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(Categories.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    
                    TextField("Comment (optional)", text: $comment)
                }
                
                Section {
                    Picker("Payment Mode", selection: $paymentMode) {
                        ForEach(PaymentMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section {
                    Picker("Spent By", selection: $spentBy) {
                        ForEach(SpentBy.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                }
                
                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle(expenditureToEdit == nil ? "Add Expenditure" : "Edit Expenditure")
            .navigationBarItems(
                leading: Button("Cancel") {
                    isPresented = false
                },
                trailing: Button("Save") {
                    saveExpenditure()
                    isPresented = false
                }
                .disabled(amountSpent.isEmpty || Double(amountSpent) == nil)
            )
        }
    }
    
    private func saveExpenditure() {
        let expenditure = expenditureToEdit ?? Expenditure(context: viewContext)
        expenditure.amount = Double(amountSpent) ?? 0
        expenditure.category = category.rawValue
        expenditure.paymentMode = paymentMode.rawValue
        expenditure.spentBy = spentBy.rawValue
        expenditure.date = date
        expenditure.comment = truncateComment(comment)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to save expenditure: \(error.localizedDescription)")
        }
    }

    private func truncateComment(_ comment: String) -> String? {
        if comment.isEmpty {
            return nil
        }
        if comment.count <= 15 {
            return comment
        }
        return String(comment.prefix(15)) + "..."
    }
}