import SwiftUI

@main
struct MontageberichtApp: App {
    @StateObject private var store = ReportStore()
    var body: some Scene {
        WindowGroup {
            ReportListView().environmentObject(store)
                .tint(Color(red: 0.08, green: 0.22, blue: 0.34))
        }
    }
}
