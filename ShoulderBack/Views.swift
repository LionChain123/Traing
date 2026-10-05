import SwiftUI
import UIKit
import Combine

struct RootView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var clock = Date()
    @State private var showStorageIssue = false
    var body: some View {
        TabView {
            NavigationStack { TodayView() }
                .tabItem { Label("今日", systemImage: "flame.fill") }
            NavigationStack { WeekView() }
                .tabItem { Label("计划", systemImage: "calendar") }
            NavigationStack { MotivationWallView() }
                .tabItem { Label("动机", systemImage: "photo.on.rectangle.angled") }
            NavigationStack { HistoryView() }
                .tabItem { Label("记录", systemImage: "chart.bar.xaxis") }
        }
        .id(TrainingStore.weekID(clock) + String(Calendar.current.component(.day, from: clock)))
        .onChange(of: scenePhase) { phase in if phase == .active { clock = Date() } }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { clock = $0 }
        .onAppear { showStorageIssue = store.persistenceError != nil }
        .onChange(of: store.persistenceError) { error in showStorageIssue = error != nil }
        .sheet(isPresented: $showStorageIssue) {
            NavigationStack {
                VStack(alignment: .leading, spacing: 20) {
                    Text(store.persistenceError ?? "").font(.body)
                    ShareLink(item: store.exportText) {
                        Label("导出原始备份", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                    Text("关闭提示后仍可查看记录；写入已暂停。")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }.padding(24).navigationTitle("数据存储提醒")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("关闭") { showStorageIssue = false }
                        }
                    }
            }
        }
    }
}

struct TodayView: View {
    @EnvironmentObject private var store: TrainingStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Label("肩背优先", systemImage: "figure.strengthtraining.traditional")
                        .font(.subheadline.weight(.bold)).foregroundStyle(Palette.lime)
                    Spacer()
                    Text(Date(), format: .dateTime.month().day()).foregroundStyle(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("每一组，\n都算数。").font(.system(size: 44, weight: .heavy, design: .rounded))
                    Text("让今天的积累，成为明天的力量。").foregroundStyle(.secondary)
                }
                ProgressCard(week: store.currentWeek)
                HStack {
                    Text("今天的训练").font(.title2.bold())
                    Spacer()
                    Text(store.today.name).foregroundStyle(.secondary)
                }
                NavigationLink {
                    WorkoutView(day: store.today, week: store.currentWeek)
                } label: {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: store.today.isStrength ? "dumbbell.fill" : "figure.walk")
                                .font(.largeTitle).foregroundStyle(Palette.lime)
                            Spacer()
                            Text(store.today.kind).font(.caption.bold()).padding(8)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                        Text(store.today.focus).font(.title2.bold()).multilineTextAlignment(.leading)
                        HStack {
                            Text("\(store.today.exercises.count) 个动作 · \(store.today.requiredKeys.count) 组 / 项")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        Text("开始训练").font(.headline).foregroundStyle(.black)
                            .frame(maxWidth: .infinity).padding(16)
                            .background(Palette.lime, in: RoundedRectangle(cornerRadius: 16))
                    }.trainingCard()
                }.buttonStyle(.plain)
                HStack(spacing: 12) {
                    Metric(value: "4", label: "力量训练 / 周")
                    Metric(value: "3", label: "有氧恢复 / 周")
                    Metric(value: "1–3", label: "目标 RIR")
                }
                PoemCard()
                MotivationPreview()
            }.padding(20).frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
        }.background(Palette.background).navigationTitle("今日")
            .toolbar(.hidden, for: .navigationBar)
    }
}

struct Metric: View {
    let value: String
    let label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value).font(.title.bold()).foregroundStyle(Palette.lime)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).padding(14)
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ProgressCard: View {
    @EnvironmentObject private var store: TrainingStore
    let week: String
    var body: some View {
        HStack(spacing: 22) {
            ZStack {
                Circle().stroke(.white.opacity(0.08), lineWidth: 9)
                Circle().trim(from: 0, to: store.progress(week: week))
                    .stroke(Palette.lime, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(store.progress(week: week) * 100))%")
                    .font(.title2.bold().monospacedDigit())
            }.frame(width: 84, height: 84).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text("本周完成度").font(.headline)
                Text("\(store.completed(store.requiredKeys, week: week)) / \(store.requiredKeys.count) 组 / 项")
                    .foregroundStyle(.secondary)
                Text("可选训练另计，保持稳定节奏。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }.trainingCard().accessibilityElement(children: .combine)
    }
}

struct WeekView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var showPrinciples = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("一周四练 · 肩背优先").foregroundStyle(.secondary)
                ForEach(store.plan.days) { day in
                    NavigationLink { WorkoutView(day: day, week: store.currentWeek) } label: {
                        HStack(spacing: 16) {
                            VStack(spacing: 6) {
                                Text(day.name).font(.headline)
                                Image(systemName: day.isStrength ? "dumbbell.fill" : "figure.walk")
                                    .foregroundStyle(day.isStrength ? Palette.lime : .cyan)
                            }.frame(width: 46)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(day.focus).font(.headline).multilineTextAlignment(.leading)
                                Text("\(store.completed(day.requiredKeys, week: store.currentWeek)) / \(day.requiredKeys.count) 已完成")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }.trainingCard()
                    }.buttonStyle(.plain)
                }
                Button { showPrinciples = true } label: {
                    Label("查看执行原则", systemImage: "book.closed").frame(maxWidth: .infinity).padding()
                }.buttonStyle(.bordered)
            }.padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(Palette.background).navigationTitle("一周计划")
            .sheet(isPresented: $showPrinciples) { PrinciplesView() }
    }
}

struct WorkoutView: View {
    @EnvironmentObject private var store: TrainingStore
    let day: TrainingDay
    let week: String
    @State private var showTimer = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(day.focus).font(.largeTitle.bold())
                HStack {
                    Text(day.kind).foregroundStyle(Palette.lime)
                    Spacer()
                    Text("\(store.completed(day.requiredKeys, week: week)) / \(day.requiredKeys.count) 已完成")
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                ForEach(day.exercises) { exercise in
                    ExerciseCard(exercise: exercise, week: week)
                }
                if !day.note.isEmpty {
                    Label(day.note, systemImage: "info.circle").font(.subheadline)
                        .foregroundStyle(.secondary).trainingCard()
                }
            }.padding(20).frame(maxWidth: 720).frame(maxWidth: .infinity)
        }.background(Palette.background).navigationTitle(day.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showTimer = true } label: { Image(systemName: "timer") }
                        .accessibilityLabel("组间休息计时")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                }
            }.sheet(isPresented: $showTimer) { RestTimerView() }
    }
}

struct ExerciseCard: View {
    @EnvironmentObject private var store: TrainingStore
    let exercise: Exercise
    let week: String
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                Text(exercise.name).font(.title3.bold())
                Spacer()
                Text(exercise.prescription).font(.subheadline.bold()).foregroundStyle(Palette.lime)
            }
            Text(exercise.detail).font(.subheadline).foregroundStyle(.secondary)
            ForEach(Array(exercise.setKeys.enumerated()), id: \.element) { index, key in
                HStack(spacing: 10) {
                    Button {
                        store.update(key, week: week) { $0.done.toggle() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: store.entry(key, week: week).done ? "checkmark.circle.fill" : "circle")
                            .font(.title2).foregroundStyle(store.entry(key, week: week).done ? Palette.lime : .secondary)
                            .frame(width: 44, height: 44)
                    }.buttonStyle(.plain)
                        .accessibilityLabel("\(exercise.name)，第 \(index + 1) 组，\(store.entry(key, week: week).done ? "已完成" : "未完成")")
                        .accessibilityHint("轻点切换完成状态")
                    Text(exercise.setKeys.count == 1 ? "完成" : "第\(index + 1)组")
                        .font(.subheadline).frame(width: 46, alignment: .leading)
                    if exercise.optionalKeys.contains(key) {
                        Text("可选").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if exercise.prescription.contains("×") {
                        TextField("kg", text: field(key, \.weight)).keyboardType(.decimalPad)
                            .accessibilityLabel("第 \(index + 1) 组重量，千克")
                            .frame(width: 58)
                        TextField("次数", text: field(key, \.reps)).keyboardType(.numberPad)
                            .accessibilityLabel("第 \(index + 1) 组次数")
                            .frame(width: 52)
                    }
                }.textFieldStyle(.roundedBorder)
            }
        }.trainingCard().disabled(store.persistenceError != nil)
    }
    private func field(_ key: String, _ path: WritableKeyPath<SetEntry, String>) -> Binding<String> {
        Binding(get: { store.entry(key, week: week)[keyPath: path] }, set: { value in
            store.update(key, week: week) { $0[keyPath: path] = value }
        })
    }
}

struct HistoryView: View {
    @EnvironmentObject private var store: TrainingStore
    @State private var confirmReset = false
    var body: some View {
        List {
            if let error = store.persistenceError {
                Section("数据存储提醒") {
                    Text(error).foregroundStyle(.orange)
                    ShareLink(item: store.exportText) { Label("导出原始备份", systemImage: "square.and.arrow.up") }
                }
            }
            Section("本周") {
                ProgressCard(week: store.currentWeek).listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
                ShareLink(item: store.exportText) { Label("导出训练记录（JSON 文本）", systemImage: "square.and.arrow.up") }
            }
            Section("历史周 · 点击查看动作记录") {
                if store.records.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("你的第一组，从今天开始。").font(.headline)
                        Text("勾选训练或填写重量后，记录会自动出现在这里。")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }.padding(.vertical, 12)
                }
                ForEach(store.records.keys.sorted(by: >), id: \.self) { week in
                    NavigationLink {
                        List(store.plan.days) { day in
                            NavigationLink { WorkoutView(day: day, week: week) } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(day.name) · \(day.focus)")
                                    Text("\(store.completed(day.requiredKeys, week: week)) / \(day.requiredKeys.count) 已完成")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }.navigationTitle("\(week) 当周")
                    } label: {
                        HStack {
                            Text("\(week) 当周")
                            Spacer()
                            Text("\(Int(store.progress(week: week) * 100))%")
                                .foregroundStyle(Palette.lime).monospacedDigit()
                        }
                    }
                }
            }
            Section {
                Button("清空本周记录", role: .destructive) { confirmReset = true }
                    .disabled(store.persistenceError != nil)
            } footer: {
                Text("数据保存在此设备。新的一周自动独立记录，过去的周记录会保留。删除 App 会删除本地数据，请定期导出。")
            }
        }.scrollContentBackground(.hidden).background(Palette.background)
            .navigationTitle("训练记录")
            .confirmationDialog("清空本周的完成状态、重量和次数？", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("清空本周", role: .destructive) { store.resetCurrentWeek() }
                Button("取消", role: .cancel) {}
            } message: { Text("历史周记录会保留，此操作无法撤销。") }
    }
}

struct PrinciplesView: View {
    @EnvironmentObject private var store: TrainingStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List(store.plan.principles) { principle in
                VStack(alignment: .leading, spacing: 10) {
                    Text(principle.title).font(.headline).foregroundStyle(Palette.lime)
                    Text(principle.body).font(.subheadline).foregroundStyle(.secondary)
                }.padding(.vertical, 8)
            }.navigationTitle("执行原则").toolbar {
                ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
            }
        }
    }
}

struct RestTimerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var duration = 90
    @State private var deadline: Date?
    @State private var remaining = 90
    private let tick = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: "timer").font(.largeTitle).foregroundStyle(Palette.lime)
                Text(deadline == nil && remaining == 0 ? "休息完成" : "组间休息")
                    .font(.title2.bold())
                Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                    .font(.system(size: 76, weight: .light, design: .rounded)).monospacedDigit()
                Picker("休息时长", selection: $duration) {
                    Text("60 秒").tag(60)
                    Text("90 秒").tag(90)
                    Text("120 秒").tag(120)
                }.pickerStyle(.segmented).disabled(deadline != nil)
                    .onChange(of: duration) { remaining = $0 }
                Button(deadline == nil ? "开始休息" : "暂停") {
                    if deadline == nil {
                        if remaining == 0 { remaining = duration }
                        deadline = Date().addingTimeInterval(Double(remaining))
                    } else {
                        if let end = deadline {
                            remaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
                        }
                        deadline = nil
                    }
                }.buttonStyle(.borderedProminent).controlSize(.large).foregroundStyle(.black)
                Button("重置") { deadline = nil; remaining = duration }
                Text("离开此页面会结束计时；后台结束时不会发送通知。")
                    .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Spacer()
            }.padding(24).background(Palette.background).navigationTitle("休息计时")
                .navigationBarTitleDisplayMode(.inline).toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
                }.onReceive(tick) { now in
                    guard let end = deadline else { return }
                    remaining = max(0, Int(ceil(end.timeIntervalSince(now))))
                    if remaining == 0 {
                        deadline = nil
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                    }
                }
        }
    }
}

struct AppPreview: PreviewProvider {
    static var previews: some View {
        RootView().environmentObject(TrainingStore()).environmentObject(MotivationStore())
            .preferredColorScheme(.dark).tint(Palette.lime)
    }
}
