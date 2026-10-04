import SwiftUI
import WidgetKit

/// Единственная точка входа для расширения виджета
@main
struct SolvoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SBTodayWidget()
        SBVisitLiveActivity()
    }
}
