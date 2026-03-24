import SwiftUI

struct DailyTasksView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedDate = Date()
    @State private var showAddTaskSheet = false
    @State private var newTaskName: String = ""
    @State private var newTaskScore: Int = 1
    @State private var selectedCategoryName: String = ""
    @State private var customCategoryName: String = ""
    @State private var searchText: String = ""

    private var isSelectedDateToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var baseCategories: [TaskCategory] {
        store.categories.filter { !($0.name == "مهام الجمعة" && !isFriday(selectedDate)) }
    }

    private var filteredCategories: [TaskCategory] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return baseCategories }

        return baseCategories.compactMap { category in
            if category.name.localizedCaseInsensitiveContains(query) {
                return category
            }

            let filteredSubCategories = category.subCategories?.compactMap { subCategory in
                let tasks = subCategory.tasks.filter { $0.name.localizedCaseInsensitiveContains(query) }
                return tasks.isEmpty ? nil : SubCategory(name: subCategory.name, tasks: tasks)
            }

            let filteredTasks = category.tasks?.filter { $0.name.localizedCaseInsensitiveContains(query) }

            let hasSubCategories = !(filteredSubCategories?.isEmpty ?? true)
            let hasTasks = !(filteredTasks?.isEmpty ?? true)

            guard hasSubCategories || hasTasks else { return nil }
            return TaskCategory(
                name: category.name,
                subCategories: hasSubCategories ? filteredSubCategories : nil,
                tasks: hasTasks ? filteredTasks : nil
            )
        }
    }

    private var selectedDateTotalTasks: Int {
        baseCategories.reduce(0) { partial, category in
            partial + tasksForCategory(category).count
        }
    }

    private var selectedDateCompletedTasks: Int {
        baseCategories.flatMap(tasksForCategory).filter { store.isTaskCompleted($0, on: selectedDate) }.count
    }

    private var selectedDateCompletion: Double {
        guard selectedDateTotalTasks > 0 else { return 0 }
        return Double(selectedDateCompletedTasks) / Double(selectedDateTotalTasks)
    }

    private var normalizedTaskName: String {
        newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedCustomCategory: String {
        customCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSaveNewTask: Bool {
        guard !normalizedTaskName.isEmpty else { return false }
        if selectedCategoryName == "مخصص" {
            return !normalizedCustomCategory.isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("تسجيل أيام سابقة")
                            .font(.headline)
                        DatePicker("اختر التاريخ", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)
                        Text("يمكنك تسجيل إنجازات أي يوم سابق هنا")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !isSelectedDateToday {
                            Button("العودة لليوم") {
                                selectedDate = Date()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .aamalCard()

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("ملخص اليوم المختار")
                                .font(.headline)
                            Spacer()
                            Text("\(selectedDateCompletedTasks)/\(selectedDateTotalTasks)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        ProgressView(value: selectedDateCompletion)
                            .tint(AamalTheme.emerald)

                        Text("\(Int(selectedDateCompletion * 100))% مكتمل")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .aamalCard()

                    if filteredCategories.isEmpty {
                        Text("لا توجد مهام مطابقة لبحثك")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                            .aamalCard()
                    } else {
                        ForEach(filteredCategories, id: \.name) { category in
                            CategorySectionView(category: category, store: store, date: selectedDate)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddTaskSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .background(AamalTheme.backgroundGradient.ignoresSafeArea())
            .navigationTitle("أعمال اليوم")
            .searchable(text: $searchText, prompt: "ابحث عن مهمة")
            .sheet(isPresented: $showAddTaskSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("تفاصيل المهمة")) {
                            TextField("اسم المهمة", text: $newTaskName)
                            Stepper(value: $newTaskScore, in: 1...20) {
                                Text("الدرجة: \(newTaskScore)")
                            }
                        }

                        Section(header: Text("التصنيف")) {
                            Picker("اختر تصنيفا", selection: $selectedCategoryName) {
                                ForEach(store.categories.map { $0.name }, id: \.self) { name in
                                    Text(name).tag(name)
                                }
                                Text("مخصص").tag("مخصص")
                            }

                            if selectedCategoryName == "مخصص" {
                                TextField("اسم التصنيف المخصص", text: $customCategoryName)
                            }
                        }

                        Section {
                            Text("سيتم حفظ المهمة مباشرة وإظهارها ضمن التصنيف المختار.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .navigationTitle("إضافة مهمة")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("حفظ") {
                                saveNewTask()
                            }
                            .disabled(!canSaveNewTask)
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") {
                                resetAddTaskForm()
                                showAddTaskSheet = false
                            }
                        }
                    }
                    .onAppear {
                        if selectedCategoryName.isEmpty {
                            selectedCategoryName = store.categories.first?.name ?? "عام"
                        }
                    }
                }
            }
        }
    }

    private func tasksForCategory(_ category: TaskCategory) -> [Task] {
        var tasks: [Task] = []
        if let subCategories = category.subCategories {
            for subCategory in subCategories {
                tasks.append(contentsOf: subCategory.tasks)
            }
        }
        if let directTasks = category.tasks {
            tasks.append(contentsOf: directTasks)
        }
        return tasks
    }

    private func isFriday(_ date: Date) -> Bool {
        Calendar.current.component(.weekday, from: date) == 6
    }

    private func saveNewTask() {
        var categoryToUse = selectedCategoryName
        if categoryToUse == "مخصص" {
            categoryToUse = normalizedCustomCategory
        }

        store.addTask(name: normalizedTaskName, score: newTaskScore, categoryName: categoryToUse)
        resetAddTaskForm()
        showAddTaskSheet = false
    }

    private func resetAddTaskForm() {
        newTaskName = ""
        newTaskScore = 1
        selectedCategoryName = store.categories.first?.name ?? ""
        customCategoryName = ""
    }
}

private struct CategorySectionView: View {
    let category: TaskCategory
    @ObservedObject var store: TaskStore
    let date: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category.name)
                .font(.headline)

            if let subCategories = category.subCategories {
                ForEach(subCategories, id: \.name) { subCategory in
                    if subCategory.tasks.allSatisfy({ store.isPrayerTask($0) }) {
                        PrayerCompactGroupList(tasks: subCategory.tasks, store: store, date: date)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(subCategory.name)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            ForEach(subCategory.tasks) { task in
                                TaskRow(task: task, store: store, date: date)
                            }
                        }
                    }
                }
            }

            if let tasks = category.tasks {
                ForEach(tasks) { task in
                    TaskRow(task: task, store: store, date: date)
                }
            }
        }
        .aamalCard()
    }
}

private struct PrayerCompactGroupList: View {
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date

    private var grouped: [String: [Task]] {
        Dictionary(grouping: tasks, by: { $0.category })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("مهام الصلاة")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(grouped.keys.sorted(), id: \.self) { prayer in
                PrayerTinyGroupRow(prayerName: prayer, tasks: grouped[prayer] ?? [], store: store, date: date)
            }
        }
    }
}

private struct PrayerTinyGroupRow: View {
    let prayerName: String
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date
    @State private var isExpanded = false

    private var remainingCount: Int {
        tasks.filter { !store.isTaskCompleted($0, on: date) }.count
    }

    private var previewTasks: [Task] {
        isExpanded ? tasks : Array(tasks.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(prayerName)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AamalTheme.emerald.opacity(0.15))
                    .foregroundColor(AamalTheme.emerald)
                    .clipShape(Capsule())

                Text("\(remainingCount) متبقية")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ForEach(previewTasks) { task in
                TaskRow(task: task, store: store, date: date)
            }

            if tasks.count > previewTasks.count {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "عرض أقل" : "+\(tasks.count - previewTasks.count) مهام أخرى")
                            .font(.caption2)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else if tasks.count > 2 {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("عرض أقل")
                            .font(.caption2)
                        Image(systemName: "chevron.up")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AamalTheme.cardBackground())
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AamalTheme.gold.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

private struct TaskRow: View {
    let task: Task
    @ObservedObject var store: TaskStore
    let date: Date

    var body: some View {
        let isCompleted = store.isTaskCompleted(task, on: date)
        HStack(spacing: 12) {
            Image(systemName: isCompleted ? "checkmark.seal.fill" : "seal")
                .foregroundColor(isCompleted ? AamalTheme.emerald : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.subheadline)
                Text("+\(task.score) نقطة")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isCompleted {
                Button(action: {
                    store.toggleTask(taskId: task.id, on: date)
                }) {
                    Text("تم")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BorderedButtonStyle())

                Button(action: {
                    store.unlogTask(taskId: task.id, on: date)
                }) {
                    Text("إلغاء التسجيل")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: {
                    store.toggleTask(taskId: task.id, on: date)
                }) {
                    Text("سجل")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .tint(AamalTheme.emerald)
            }
        }
        .padding(.vertical, 4)
    }
}
