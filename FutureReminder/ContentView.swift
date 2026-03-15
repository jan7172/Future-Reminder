import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Reminder> { !$0.isDone },
           sort: \Reminder.createdAt, order: .reverse)
    private var activeReminders: [Reminder]

    @Query(filter: #Predicate<Reminder> { $0.isDone },
           sort: \Reminder.createdAt, order: .reverse)
    private var doneReminders: [Reminder]

    @State private var showAdd = false
    @State private var showDebug = false

    var body: some View {
        NavigationStack {
            List {
                // Aktive Reminder
                if activeReminders.isEmpty && doneReminders.isEmpty {
                    ContentUnavailableView(
                        "No Reminders",
                        systemImage: "mappin.slash",
                        description: Text("Add a reminder and set a location as trigger.")
                    )
                } else {
                    if !activeReminders.isEmpty {
                        Section("Active") {
                            ForEach(activeReminders) { reminder in
                                NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                                    ReminderRow(reminder: reminder)
                                }
                            }
                            .onDelete(perform: deleteActive)
                        }
                    }

                    // Erledigte Reminder
                    if !doneReminders.isEmpty {
                        Section("Done") {
                            ForEach(doneReminders) { reminder in
                                NavigationLink(destination: ReminderDetailView(reminder: reminder)) {
                                    ReminderRow(reminder: reminder, isDone: true)
                                }
                            }
                            .onDelete(perform: deleteDone)
                        }
                    }
                }
            }
            .navigationTitle("Future Reminder")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 1.5)
                            .onEnded { _ in
                                showDebug = true
                            }
                    )
                }
            }
            .sheet(isPresented: $showAdd) {
                AddReminderView()
            }
            .sheet(isPresented: $showDebug) {
                DebugView()
            }
            .onAppear {
                let all = activeReminders + doneReminders
                LocationManager.shared.refreshAllGeofences(reminders: all)
            }
        }
    }

    private func deleteActive(at offsets: IndexSet) {
        for index in offsets {
            let reminder = activeReminders[index]
            LocationManager.shared.cancelNotification(for: reminder)
            modelContext.delete(reminder)
        }
    }

    private func deleteDone(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(doneReminders[index])
        }
    }
}

struct ReminderRow: View {
    let reminder: Reminder
    var isDone: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reminder.title)
                .font(.headline)
                .foregroundStyle(isDone ? .secondary : .primary)
                .strikethrough(isDone)
            if !reminder.locationName.isEmpty {
                Label(reminder.locationName, systemImage: "mappin.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if !reminder.note.isEmpty {
                Text(reminder.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
