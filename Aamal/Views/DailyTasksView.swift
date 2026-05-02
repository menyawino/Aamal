import SwiftUI

private enum AddTaskPlacement: String, CaseIterable, Identifiable {
    case allPrayers
    case singlePrayer
    case bundle
    case category
    case customCategory

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allPrayers:
            return "كل الصلوات"
        case .singlePrayer:
            return "صلاة واحدة"
        case .bundle:
            return "حزمة"
        case .category:
            return "تصنيف علوي"
        case .customCategory:
            return "تصنيف مخصص"
        }
    }
}

struct DailyTasksView: View {
    @ObservedObject var store: TaskStore
    @State private var selectedDate = Date()
    @State private var showAddTaskSheet = false
    @State private var newTaskName: String = ""
    @State private var newTaskScore: Int = 1
    @State private var selectedPlacement: AddTaskPlacement = .bundle
    @State private var selectedPrayerName: String = ""
    @State private var selectedBundleID: String = ""
    @State private var selectedCategoryName: String = ""
    @State private var customCategoryName: String = ""
    @State private var searchText: String = ""
    @State private var actionFeedback: TaskActionFeedback?
    @State private var feedbackDismissWorkItem: DispatchWorkItem?

    private let contentHorizontalPadding: CGFloat = AamalTheme.sectionSpacing + 4
    private let contentTopPadding: CGFloat = AamalTheme.contentSpacing + 2
    private let contentBottomPadding: CGFloat = AamalTheme.screenBottomInset + AamalTheme.contentSpacing
    private let cardStackSpacing: CGFloat = AamalTheme.screenSpacing + 4
    private let topControlsBottomSpacing: CGFloat = AamalTheme.contentSpacing + 2

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
        store.availableTasks(for: baseCategories, on: selectedDate).count
    }

    private var selectedDateCompletedTasks: Int {
        store.availableTasks(for: baseCategories, on: selectedDate)
            .filter { store.isTaskCompleted($0, on: selectedDate) }
            .count
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

    private var prayerTargets: [PrayerTaskTarget] {
        store.prayerTaskTargets
    }

    private var bundleTargets: [BundleTaskTarget] {
        store.nonPrayerBundleTargets
    }

    private var categoryTargets: [String] {
        store.categories.map(\ .name)
    }

    private var selectedBundleTarget: BundleTaskTarget? {
        bundleTargets.first(where: { $0.id == selectedBundleID })
    }

    private var canSaveNewTask: Bool {
        guard !normalizedTaskName.isEmpty else { return false }
        switch selectedPlacement {
        case .allPrayers:
            return !prayerTargets.isEmpty
        case .singlePrayer:
            return !selectedPrayerName.isEmpty
        case .bundle:
            return selectedBundleTarget != nil
        case .category:
            return !selectedCategoryName.isEmpty
        case .customCategory:
            return !normalizedCustomCategory.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: cardStackSpacing) {
                    HStack(spacing: 12) {
                        Button(action: { showAddTaskSheet = true }) {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .frame(width: 56, height: 56)
                        }
                        .foregroundColor(AamalTheme.emerald)
                        .background(
                            Circle()
                                .fill(AamalTheme.tonalBackground(for: AamalTheme.emerald))
                                .overlay(
                                    Circle()
                                        .stroke(AamalTheme.emerald.opacity(0.18), lineWidth: 1)
                                )
                        )

                        AamalSearchField(text: $searchText, prompt: "ابحث عن مهمة", tint: AamalTheme.gold)
                    }
                    .padding(.bottom, topControlsBottomSpacing)
                    .aamalEntrance(0)

                    VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
                        AamalSectionHeader(
                            title: "تسجيل أيام سابقة",
                            subtitle: "يمكنك تسجيل إنجازات أي يوم سابق هنا.",
                            tint: AamalTheme.gold,
                            systemImage: "calendar.badge.clock"
                        )

                        DatePicker("اختر التاريخ", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                            .datePickerStyle(.compact)

                        if !isSelectedDateToday {
                            Button("العودة لليوم") {
                                selectedDate = Date()
                            }
                            .buttonStyle(AamalSecondaryButtonStyle())
                        }
                    }
                    .aamalCard()
                    .aamalEntrance(1)

                    VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
                        AamalSectionHeader(
                            title: "ملخص اليوم المختار",
                            subtitle: "\(selectedDateCompletedTasks)/\(selectedDateTotalTasks) مهمة مسجلة حتى الآن",
                            tint: AamalTheme.emerald,
                            systemImage: "list.clipboard"
                        )

                        ProgressView(value: selectedDateCompletion)
                            .tint(AamalTheme.emerald)

                        Text("\(Int(selectedDateCompletion * 100))% مكتمل")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack(spacing: 10) {
                            AamalStatPill(
                                title: "المتبقي",
                                value: "\(max(0, selectedDateTotalTasks - selectedDateCompletedTasks))",
                                tint: AamalTheme.gold,
                                layout: .compact,
                                showsIndicator: true
                            )

                            AamalStatPill(
                                title: "المسجل",
                                value: "\(selectedDateCompletedTasks)",
                                tint: AamalTheme.emerald,
                                layout: .compact,
                                showsIndicator: true
                            )
                        }
                    }
                    .aamalCard()
                    .aamalEntrance(2)

                    if filteredCategories.isEmpty {
                        Text("لا توجد مهام مطابقة لبحثك")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                            .aamalCard()
                            .aamalEntrance(3)
                    } else {
                        ForEach(Array(filteredCategories.enumerated()), id: \.element.name) { index, category in
                            CategorySectionView(
                                category: category,
                                store: store,
                                date: selectedDate,
                                onTaskAction: presentFeedback
                            )
                            .aamalEntrance(index + 3)
                        }
                    }
                }
                .padding(.top, contentTopPadding)
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.bottom, contentBottomPadding)
            }
            .safeAreaInset(edge: .bottom) {
                if let actionFeedback {
                    TaskActionBanner(
                        feedback: actionFeedback,
                        undoAction: { undo(feedback: actionFeedback) },
                        dismissAction: dismissFeedback
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .transition(AamalTransition.banner)
                }
            }
            .navigationTitle("أعمال اليوم")
            .navigationBarTitleDisplayMode(.inline)
            .aamalScreen()
            .animation(AamalMotion.banner, value: actionFeedback != nil)
            .sheet(isPresented: $showAddTaskSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("تفاصيل المهمة")) {
                            TextField("اسم المهمة", text: $newTaskName)
                            Stepper(value: $newTaskScore, in: 1...20) {
                                Text("الدرجة: \(newTaskScore)")
                            }
                        }

                        Section(header: Text("جهة الإضافة")) {
                            Picker("نوع الإضافة", selection: $selectedPlacement) {
                                ForEach(AddTaskPlacement.allCases) { placement in
                                    Text(placement.title).tag(placement)
                                }
                            }

                            switch selectedPlacement {
                            case .allPrayers:
                                Text("سيتم إنشاء نسخة من المهمة داخل كل مجموعة صلاة.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                            case .singlePrayer:
                                Picker("الصلاة", selection: $selectedPrayerName) {
                                    ForEach(prayerTargets) { target in
                                        Text(target.prayerName).tag(target.prayerName)
                                    }
                                }

                            case .bundle:
                                Picker("الحزمة", selection: $selectedBundleID) {
                                    ForEach(bundleTargets) { target in
                                        Text("\(target.bundleName) • \(target.categoryName)")
                                            .tag(target.id)
                                    }
                                }

                            case .category:
                                Picker("التصنيف", selection: $selectedCategoryName) {
                                    ForEach(categoryTargets, id: \.self) { name in
                                        Text(name).tag(name)
                                    }
                                }

                            case .customCategory:
                                TextField("اسم التصنيف المخصص", text: $customCategoryName)
                            }
                        }

                        Section {
                            Text("سيتم حفظ المهمة مباشرة وإظهارها في الجهة التي اخترتها للتسجيل والمتابعة.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .aamalForm()
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
                        synchronizeAddTaskSelections()
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
        switch selectedPlacement {
        case .allPrayers:
            store.addTask(name: normalizedTaskName, score: newTaskScore, toAllPrayersAvailableFrom: selectedDate)

        case .singlePrayer:
            store.addTask(name: normalizedTaskName, score: newTaskScore, toPrayer: selectedPrayerName, availableFrom: selectedDate)

        case .bundle:
            guard let bundleTarget = selectedBundleTarget else { return }
            store.addTask(
                name: normalizedTaskName,
                score: newTaskScore,
                toBundle: bundleTarget.bundleName,
                inCategory: bundleTarget.categoryName,
                availableFrom: selectedDate
            )

        case .category:
            store.addTask(name: normalizedTaskName, score: newTaskScore, toCategory: selectedCategoryName, availableFrom: selectedDate)

        case .customCategory:
            store.addTask(name: normalizedTaskName, score: newTaskScore, toCategory: normalizedCustomCategory, availableFrom: selectedDate)
        }
        resetAddTaskForm()
        showAddTaskSheet = false
    }

    private func resetAddTaskForm() {
        newTaskName = ""
        newTaskScore = 1
        selectedPlacement = .bundle
        synchronizeAddTaskSelections()
        customCategoryName = ""
    }

    private func synchronizeAddTaskSelections() {
        if selectedPrayerName.isEmpty || !prayerTargets.contains(where: { $0.prayerName == selectedPrayerName }) {
            selectedPrayerName = prayerTargets.first?.prayerName ?? ""
        }

        if selectedBundleID.isEmpty || !bundleTargets.contains(where: { $0.id == selectedBundleID }) {
            selectedBundleID = bundleTargets.first?.id ?? ""
        }

        if selectedCategoryName.isEmpty || !categoryTargets.contains(selectedCategoryName) {
            selectedCategoryName = categoryTargets.first ?? "عام"
        }
    }

    private func presentFeedback(_ feedback: TaskActionFeedback) {
        feedbackDismissWorkItem?.cancel()
        withAnimation(AamalMotion.banner) {
            actionFeedback = feedback
        }

        let workItem = DispatchWorkItem {
            withAnimation(AamalMotion.banner) {
                actionFeedback = nil
            }
        }
        feedbackDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: workItem)
    }

    private func dismissFeedback() {
        feedbackDismissWorkItem?.cancel()
        withAnimation(AamalMotion.banner) {
            actionFeedback = nil
        }
    }

    private func undo(feedback: TaskActionFeedback) {
        feedbackDismissWorkItem?.cancel()
        withAnimation(AamalMotion.cardState) {
            switch feedback.kind {
            case .logged:
                _ = store.unlogTask(taskId: feedback.task.id, on: feedback.date)
            case .unlogged:
                _ = store.logTask(taskId: feedback.task.id, on: feedback.date)
            }
            actionFeedback = nil
        }
    }
}

private struct CategorySectionView: View {
    let category: TaskCategory
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void

    var body: some View {
        let visibleSubCategories = category.subCategories?.compactMap { subCategory -> SubCategory? in
            let visibleTasks = subCategory.tasks.filter { store.isTaskActive($0, on: date) }
            guard !visibleTasks.isEmpty else { return nil }
            return SubCategory(name: subCategory.name, tasks: visibleTasks)
        }

        let visibleDirectTasks = category.tasks?.filter { store.isTaskActive($0, on: date) }

        let visibleCount = (visibleSubCategories?.reduce(0) { $0 + $1.tasks.count } ?? 0) + (visibleDirectTasks?.count ?? 0)

        VStack(alignment: .leading, spacing: AamalTheme.sectionSpacing) {
            AamalSectionHeader(
                title: category.name,
                subtitle: visibleCount == 0 ? "لا توجد مهام فعالة لهذا اليوم." : "\(visibleCount) مهمة فعالة ضمن هذا القسم.",
                tint: AamalTheme.emerald,
                systemImage: "checklist.checked"
            )

            if let subCategories = visibleSubCategories {
                ForEach(subCategories, id: \.name) { subCategory in
                    if subCategory.tasks.allSatisfy({ store.isPrayerTask($0) }) {
                        PrayerCompactGroupList(
                            tasks: subCategory.tasks,
                            store: store,
                            date: date,
                            onTaskAction: onTaskAction
                        )
                    } else {
                        TaskGroupSection(
                            title: subCategory.name,
                            tasks: subCategory.tasks,
                            store: store,
                            date: date,
                            onTaskAction: onTaskAction
                        )
                    }
                }
            }

            if let tasks = visibleDirectTasks {
                TaskGroupSection(tasks: tasks, store: store, date: date, onTaskAction: onTaskAction)
            }
        }
        .aamalCard()
    }
}

private struct TaskGroupSection: View {
    let title: String?
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void
    @State private var showCompletedTasks = false

    init(title: String? = nil, tasks: [Task], store: TaskStore, date: Date, onTaskAction: @escaping (TaskActionFeedback) -> Void) {
        self.title = title
        self.tasks = tasks
        self.store = store
        self.date = date
        self.onTaskAction = onTaskAction
    }

    private var activeTasks: [Task] {
        tasks.filter { !store.isTaskCompleted($0, on: date) }
    }

    private var completedTasks: [Task] {
        tasks.filter { store.isTaskCompleted($0, on: date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            if let title {
                HStack {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()

                    if !completedTasks.isEmpty {
                        Text("\(completedTasks.count) مسجلة")
                            .font(.caption2)
                            .foregroundColor(AamalTheme.emerald)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AamalTheme.emerald.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
            }

            if activeTasks.isEmpty {
                Text("تم تسجيل كل المهام")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(activeTasks) { task in
                    TaskRow(task: task, store: store, date: date, onTaskAction: onTaskAction)
                        .transition(AamalTransition.cardState)
                }
            }

            if !completedTasks.isEmpty {
                CompletedTasksDisclosure(
                    tasks: completedTasks,
                    isExpanded: $showCompletedTasks,
                    store: store,
                    date: date,
                    onTaskAction: onTaskAction
                )
            }
        }
        .animation(AamalMotion.cardState, value: activeTasks.map(\.id))
        .animation(AamalMotion.cardState, value: completedTasks.map(\.id))
    }
}

private struct PrayerCompactGroupList: View {
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void

    private var grouped: [String: [Task]] {
        Dictionary(grouping: tasks, by: { $0.category })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.contentSpacing) {
            AamalSectionHeader(
                title: "مهام الصلاة",
                subtitle: "مرتبة حسب وقت الصلاة لليوم المختار.",
                tint: AamalTheme.gold,
                systemImage: "moon.stars"
            )

            ForEach(grouped.keys.sorted(), id: \.self) { prayer in
                PrayerTinyGroupRow(
                    prayerName: prayer,
                    tasks: grouped[prayer] ?? [],
                    store: store,
                    date: date,
                    onTaskAction: onTaskAction
                )
            }
        }
    }
}

private struct PrayerTinyGroupRow: View {
    let prayerName: String
    let tasks: [Task]
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void
    @State private var isExpanded = false
    @State private var showCompletedTasks = false

    private var remainingCount: Int {
        tasks.filter { !store.isTaskCompleted($0, on: date) }.count
    }

    private var activeTasks: [Task] {
        tasks.filter { !store.isTaskCompleted($0, on: date) }
    }

    private var completedTasks: [Task] {
        tasks.filter { store.isTaskCompleted($0, on: date) }
    }

    private var previewTasks: [Task] {
        let source = activeTasks
        return isExpanded ? source : Array(source.prefix(2))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.compactSpacing) {
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

            if previewTasks.isEmpty {
                Text("تم تسجيل مهام هذه الصلاة")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            } else {
                ForEach(previewTasks) { task in
                    TaskRow(task: task, store: store, date: date, onTaskAction: onTaskAction)
                        .transition(AamalTransition.cardState)
                }
            }

            if activeTasks.count > previewTasks.count {
                Button(action: {
                    withAnimation(AamalMotion.cardState) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack(spacing: 4) {
                        Text(isExpanded ? "عرض أقل" : "+\(activeTasks.count - previewTasks.count) مهام أخرى")
                            .font(.caption2)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            } else if activeTasks.count > 2 {
                Button(action: {
                    withAnimation(AamalMotion.cardState) {
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

            if !completedTasks.isEmpty {
                CompletedTasksDisclosure(
                    tasks: completedTasks,
                    isExpanded: $showCompletedTasks,
                    store: store,
                    date: date,
                    onTaskAction: onTaskAction
                )
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
        .animation(AamalMotion.cardState, value: activeTasks.map(\.id))
        .animation(AamalMotion.cardState, value: completedTasks.map(\.id))
    }
}

private struct CompletedTasksDisclosure: View {
    let tasks: [Task]
    @Binding var isExpanded: Bool
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AamalTheme.compactSpacing) {
            Button(action: {
                withAnimation(AamalMotion.cardState) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "checkmark.circle")
                        .foregroundColor(AamalTheme.emerald)
                    Text(isExpanded ? "إخفاء المسجلة" : "عرض المسجلة (\(tasks.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(tasks) { task in
                        CompletedTaskRow(task: task, store: store, date: date, onTaskAction: onTaskAction)
                            .transition(AamalTransition.cardState)
                    }
                }
            }
        }
    }
}

private struct TaskRow: View {
    let task: Task
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void
    @State private var showDeleteConfirmation = false
    @State private var showEditSheet = false

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
                    withAnimation(AamalMotion.cardState) {
                        if store.unlogTask(taskId: task.id, on: date) {
                            onTaskAction(.init(task: task, date: date, kind: .unlogged))
                        }
                    }
                }) {
                    Text("تم")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                .buttonStyle(AamalChipButtonStyle())

                Button(action: {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if store.unlogTask(taskId: task.id, on: date) {
                            onTaskAction(.init(task: task, date: date, kind: .unlogged))
                        }
                    }
                }) {
                    Text("إلغاء التسجيل")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))
            } else {
                Button(action: {
                    withAnimation(AamalMotion.cardState) {
                        if store.logTask(taskId: task.id, on: date) {
                            onTaskAction(.init(task: task, date: date, kind: .logged))
                        }
                    }
                }) {
                    Text("سجل")
                        .font(.subheadline)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                }
                    .buttonStyle(AamalChipButtonStyle(prominent: true))
            }

            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("تعديل المهمة", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("حذف المهمة", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.button)
        }
        .padding(.vertical, 4)
        .confirmationDialog(
            "حذف المهمة",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("حذف نهائيًا", role: .destructive) {
                store.removeTask(taskId: task.id)
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم حذف المهمة من جميع القوائم والتسجيلات المحفوظة.")
        }
        .sheet(isPresented: $showEditSheet) {
            TaskEditorSheet(task: task, store: store)
        }
    }
}

private struct CompletedTaskRow: View {
    let task: Task
    @ObservedObject var store: TaskStore
    let date: Date
    let onTaskAction: (TaskActionFeedback) -> Void
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AamalTheme.emerald)
                .font(.caption)

            VStack(alignment: .leading, spacing: 2) {
                Text(task.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("+\(task.score) نقطة")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.75))
            }

            Spacer()

            Button(action: {
                withAnimation(AamalMotion.cardState) {
                    if store.unlogTask(taskId: task.id, on: date) {
                        onTaskAction(.init(task: task, date: date, kind: .unlogged))
                    }
                }
            }) {
                Text("تراجع")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
            }
            .buttonStyle(AamalChipButtonStyle(tint: AamalTheme.gold))

            Menu {
                Button {
                    showEditSheet = true
                } label: {
                    Label("تعديل المهمة", systemImage: "square.and.pencil")
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("حذف المهمة", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .menuStyle(.button)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(AamalTheme.emerald.opacity(0.08))
        )
        .confirmationDialog(
            "حذف المهمة",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("حذف نهائيًا", role: .destructive) {
                store.removeTask(taskId: task.id)
            }
            Button("إلغاء", role: .cancel) {}
        } message: {
            Text("سيتم حذف المهمة من جميع القوائم والتسجيلات المحفوظة.")
        }
        .sheet(isPresented: $showEditSheet) {
            TaskEditorSheet(task: task, store: store)
        }
    }
}

private struct TaskEditorSheet: View {
    let task: Task
    @ObservedObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var draftScore: Int

    init(task: Task, store: TaskStore) {
        self.task = task
        self.store = store
        _draftName = State(initialValue: task.name)
        _draftScore = State(initialValue: task.score)
    }

    private var normalizedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("تفاصيل المهمة")) {
                    TextField("اسم المهمة", text: $draftName)

                    Stepper(value: $draftScore, in: 1...20) {
                        Text("الدرجة: \(draftScore)")
                    }
                }

                Section(header: Text("التصنيف الحالي")) {
                    Text(task.category)
                        .foregroundColor(.secondary)
                }
            }
            .aamalForm()
            .navigationTitle("تعديل المهمة")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        if store.updateTask(taskId: task.id, name: normalizedName, score: draftScore) {
                            dismiss()
                        }
                    }
                    .disabled(normalizedName.isEmpty)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("إلغاء") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct TaskActionBanner: View {
    let feedback: TaskActionFeedback
    let undoAction: () -> Void
    let dismissAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: feedback.kind.symbolName)
                .font(.headline)
                .foregroundColor(feedback.kind.tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(feedback.kind.title)
                    .font(.subheadline.weight(.semibold))
                Text(feedback.message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Button("تراجع", action: undoAction)
                .buttonStyle(AamalChipButtonStyle(tint: feedback.kind.tint, prominent: true))
                .controlSize(.small)

            Button(action: dismissAction) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(feedback.kind.tint.opacity(0.16), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 6)
        )
    }
}

private struct TaskActionFeedback: Identifiable {
    enum Kind {
        case logged
        case unlogged

        var title: String {
            switch self {
            case .logged:
                return "تم تسجيل المهمة"
            case .unlogged:
                return "تم التراجع"
            }
        }

        var symbolName: String {
            switch self {
            case .logged:
                return "checkmark.circle.fill"
            case .unlogged:
                return "arrow.uturn.backward.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .logged:
                return AamalTheme.emerald
            case .unlogged:
                return AamalTheme.gold
            }
        }
    }

    let id = UUID()
    let task: Task
    let date: Date
    let kind: Kind

    var message: String {
        switch kind {
        case .logged:
            return "\(task.name) أصبحت ضمن المهام المسجلة ويمكن التراجع فورًا."
        case .unlogged:
            return "أزلنا \(task.name) من المسجلة، ويمكنك إعادتها بضغطة واحدة."
        }
    }
}
