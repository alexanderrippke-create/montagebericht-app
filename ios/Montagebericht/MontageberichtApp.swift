import SwiftUI

@main
struct MontageberichtApp: App {
    @StateObject private var store = ReportStore()
    var body: some Scene {
        WindowGroup {
            ReportListView().environmentObject(store)
                .tint(Color(uiColor: .systemBlue))
        }
    }
}
