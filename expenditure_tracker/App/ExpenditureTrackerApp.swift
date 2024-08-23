//
//  ExpenditureTrackerApp.swift
//  ExpenditureTracker
//
//  Created by Navin Muthuswamy on 21/08/24.
//

import SwiftUI

@main
struct ExpenditureTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
