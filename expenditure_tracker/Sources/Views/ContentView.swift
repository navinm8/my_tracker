import SwiftUI
import Charts

struct ContentView: View {
    @State private var showAddExpenditure = false
    @State private var navigateToDashboard = false
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Expenditure.date, ascending: true)],
        animation: .default)
    private var expenditures: FetchedResults<Expenditure>

    var body: some View {
        NavigationView {
            VStack {
                Spacer().frame(height: 10)
                
                Chart {
                    ForEach(groupedExpenditures, id: \.month) { group in
                        ForEach(group.sortedCategories, id: \.category) { categoryData in
                            BarMark(
                                x: .value("Month", group.month, unit: .month),
                                y: .value("Amount", categoryData.amount)
                            )
                            .foregroundStyle(by: .value("Category", categoryData.category))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .month)) { value in
                        if let date = value.as(Date.self) {
                            AxisValueLabel(format: .dateTime.month(.abbreviated), centered: true)
                        }
                    }
                }
                .chartXScale(domain: chartXDomain)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("₹\(intValue)")
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...maxYValue)
                .chartLegend(position: .bottom, spacing: 20)
                .chartLegend(.visible)
                .frame(height: 300)
                .padding()
                .onTapGesture {
                    navigateToDashboard = true
                }

                Spacer()

                Button(action: {
                    showAddExpenditure = true
                }) {
                    Text("Add Expenditure")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .navigationTitle("Expenditure Tracker")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: DashboardView(), isActive: $navigateToDashboard) {
                        Text("Dashboard")
                    }
                }
            }
            .sheet(isPresented: $showAddExpenditure) {
                AddExpenditureView(isPresented: $showAddExpenditure)
            }
        }
    }

    private var maxYValue: Double {
        let maxTotalAmount = groupedExpenditures.map { group in
            group.categoryAmounts.values.reduce(0, +)
        }.max() ?? 0
        return ceil((maxTotalAmount * 1.1) / 1000) * 1000
    }

    private var chartXDomain: ClosedRange<Date> {
        let calendar = Calendar.current
        let endDate = calendar.date(byAdding: .day, value: 15, to: Date()) ?? Date()
        let startDate = calendar.date(byAdding: .month, value: -11, to: endDate)!
        return startDate...endDate
    }

    private var groupedExpenditures: [(month: Date, categoryAmounts: [String: Double], sortedCategories: [(category: String, amount: Double)])] {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -11, to: endDate)!
        
        let monthRange = stride(from: startDate, through: endDate, by: 3600 * 24 * 30)
            .map { calendar.startOfMonth(for: $0) }
        
        let groupedDict = Dictionary(grouping: expenditures) { expenditure in
            calendar.startOfMonth(for: expenditure.date ?? Date())
        }
        
        return monthRange.map { month in
            let monthExpenditures = groupedDict[month] ?? []
            let categoryAmounts = Dictionary(grouping: monthExpenditures, by: { $0.category ?? "Unknown" })
                .mapValues { exps in exps.reduce(0) { $0 + $1.amount } }
            
            // Ensure all categories are represented, even if there's no expenditure
            let allCategoryAmounts = Categories.allCases.reduce(into: [String: Double]()) { result, category in
                result[category.rawValue] = categoryAmounts[category.rawValue] ?? 0
            }
            
            let sortedCategories = allCategoryAmounts.map { (category: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }
            
            return (month: month, categoryAmounts: allCategoryAmounts, sortedCategories: sortedCategories)
        }
    }
}

// Helper extension to get start of month
extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components)!
    }
}

enum Categories: String, CaseIterable, Identifiable {
    case groceries = "🛒 Groceries"
    case online_shopping = "🛒 E-Commerce"
    case shopping = "🛍️ Shopping"
    case travel = "✈️ Travel"
    case restaurant = "🍔 Restaurant"
    case apparels = "👕 Apparels"
    case petrol = "⛽ Petrol"
    case hospital = "🏥 Hospital"
    case toll = "🛣️ Toll"
    case saloon = "💇 Saloon"
    case elearning = "💻 E-Learning"
    case automobile_services = "🚗 Services"
    case other = "💰 Other"

    var id: String { self.rawValue }
}
enum PaymentMode: String, CaseIterable, Identifiable {
    case cash = "💵 Cash"
    case upi = "📲 UPI"
    case debitcard = "💳 Debit Card"
    case creditcard = "💳 Credit Card"
    
    var id: String { self.rawValue }
}
enum SpentBy: String, CaseIterable, Identifiable {
    case navin = "🧑🏻 Navin"
    case ranjini = "👧🏻 Ranjini"
    
    var id: String { self.rawValue }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
