import Foundation
import SwiftUI
import Combine

struct CueEvent: Identifiable {
    let id = UUID()
    let date: Date
    let note: String
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()
    
    @Published var events: [CueEvent] = []
    
    init() {}
    
    func log(note: String) {
        let event = CueEvent(date: Date(), note: note)
        events.append(event)
    }
}

struct HistoryView: View {
    @ObservedObject var store = HistoryStore.shared
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    var body: some View {
        List(store.events) { event in
            VStack(alignment: .leading) {
                Text(dateFormatter.string(from: event.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(event.note)
                    .font(.body)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("Cue History")
    }
}

#Preview {
    NavigationView {
        HistoryView()
    }
}
