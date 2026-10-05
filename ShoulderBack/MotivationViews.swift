import SwiftUI
import PhotosUI
import UIKit

struct PoemCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                    Text("不要温和的走进那个良夜").font(.title.bold())
                    Text("DO NOT GO GENTLE INTO THAT GOOD NIGHT")
                        .font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary)
            }.padding(.leading, 18).padding(.vertical, 8)
                .overlay(alignment: .leading) { Rectangle().fill(.red).frame(width: 4) }
            VStack(alignment: .leading, spacing: 12) {
                Text("“Do not go gentle into that good night.\nRage, rage against the dying of the light.”")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Text("不要温和地走进那个良夜。怒斥吧，怒斥那光明的消逝。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }.frame(maxWidth: .infinity, alignment: .leading).trainingCard()
    }
}

struct MotivationPreview: View {
    @EnvironmentObject private var wall: MotivationStore
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink { MotivationWallView() } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("TRAINING MOTIVATION").font(.caption.bold()).tracking(1.5).foregroundStyle(Palette.lime)
                        Text("目标感 · 训练动机墙").font(.title2.bold())
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right").foregroundStyle(Palette.lime)
                }
            }.buttonStyle(.plain)
            Text("不是为了“练完”，而是为了把体型一点点雕出来。")
                .font(.subheadline).foregroundStyle(.secondary)
            if wall.cards.isEmpty {
                NavigationLink { MotivationWallView() } label: {
                    Label("添加你的第一张动机图片", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity).padding(24)
                        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(wall.cards.prefix(4)) { card in
                            NavigationLink { MotivationWallView() } label: {
                                MotivationTile(card: card).frame(width: 245)
                            }.buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

struct MotivationTile: View {
    @EnvironmentObject private var wall: MotivationStore
    let card: MotivationCard
    var height: CGFloat = 320
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GeometryReader { proxy in
                if let image = wall.image(for: card) {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height).clipped()
                } else {
                    Palette.panel.overlay {
                        Image(systemName: "photo").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
            }
            LinearGradient(colors: [.clear, .black.opacity(0.10), .black.opacity(0.92)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 8) {
                Text(card.title).font(.title3.bold()).foregroundStyle(.white).lineLimit(3)
                if !card.subtitle.isEmpty {
                    Text(card.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.8)).lineLimit(3)
                }
            }.padding(20)
        }.frame(height: height).clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.10)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(card.title + "。" + card.subtitle)
    }
}

struct MotivationWallView: View {
    @EnvironmentObject private var wall: MotivationStore
    @State private var draft: MotivationCard?
    @State private var showManage = false
    @State private var pendingDelete: MotivationCard?
    @State private var errorText: String?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("不是为了“练完”，而是为了把体型一点点雕出来。")
                    .foregroundStyle(.secondary)
                if let message = wall.loadError {
                    Text(message).foregroundStyle(.orange).trainingCard()
                }
                if wall.cards.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled").font(.largeTitle).foregroundStyle(Palette.lime)
                        Text("让目标看得见").font(.title2.bold())
                        Text("选择一张让你想去训练的图片，写下你的目标。")
                            .foregroundStyle(.secondary).multilineTextAlignment(.center)
                        Button("添加动机图片") { add() }.buttonStyle(.borderedProminent).foregroundStyle(.black)
                            .disabled(!wall.canEdit)
                    }.frame(maxWidth: .infinity).trainingCard()
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 18)], spacing: 18) {
                        ForEach(wall.cards) { card in
                            Button { draft = card } label: { MotivationTile(card: card, height: 400) }
                                .buttonStyle(.plain).disabled(!wall.canEdit)
                                .accessibilityHint("轻点编辑图片与文字")
                                .contextMenu {
                                    Button("编辑", systemImage: "pencil") { draft = card }
                                    Button("删除", systemImage: "trash", role: .destructive) { pendingDelete = card }
                                }
                        }
                    }
                }
                PoemCard()
            }.padding(20).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Palette.background).navigationTitle("训练动机墙")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button { showManage = true } label: { Image(systemName: "slider.horizontal.3") }
                            .accessibilityLabel("管理和排序动机墙")
                        Button { add() } label: { Image(systemName: "plus") }
                            .accessibilityLabel("添加动机图片")
                    }.disabled(!wall.canEdit)
                }
            }
            .sheet(item: $draft) { card in MotivationEditor(card: card) }
            .sheet(isPresented: $showManage) { MotivationManager() }
            .confirmationDialog("删除这张动机卡片？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                Button("删除", role: .destructive) {
                    if let card = pendingDelete {
                        do { try wall.delete(card) } catch { errorText = error.localizedDescription }
                    }
                    pendingDelete = nil
                }
            } message: { Text("只删除动机墙中的副本，相册原图会保留。") }
            .alert("保存失败", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                Button("好", role: .cancel) { errorText = nil }
            } message: { Text(errorText ?? "") }
    }
    private func add() { draft = MotivationCard(id: UUID().uuidString, title: "", subtitle: "") }
}

struct MotivationEditor: View {
    @EnvironmentObject private var wall: MotivationStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MotivationCard
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var jpeg: Data?
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var imageRevision = UUID()
    init(card: MotivationCard) { _draft = State(initialValue: card) }
    private var previewImage: UIImage? {
        if let jpeg { return UIImage(data: jpeg) }
        return wall.image(for: draft)
    }
    private var canSave: Bool {
        !isLoading && !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        draft.title.count <= 80 && draft.subtitle.count <= 240 && previewImage != nil && wall.canEdit
    }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if let image = previewImage {
                        Image(uiImage: image).resizable().scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .accessibilityLabel("动机卡片图片预览")
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(previewImage == nil ? "从相册选择图片" : "更换图片", systemImage: "photo.on.rectangle")
                    }.disabled(isLoading)
                    if isLoading { ProgressView("正在读取图片…") }
                } footer: {
                    Text("只读取你选中的照片，并保存到 App 内。相册原图删除后，动机墙仍会保留副本。")
                }
                Section("你的目标") {
                    TextField("标题，例如：肩背要撑起来", text: $draft.title, axis: .vertical)
                    Text("\(draft.title.count) / 80 字").font(.caption).foregroundStyle(.secondary)
                    TextField("说明（可选）", text: $draft.subtitle, axis: .vertical).lineLimit(2...5)
                    Text("\(draft.subtitle.count) / 240 字").font(.caption).foregroundStyle(.secondary)
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.orange) }
                }
            }.navigationTitle(draft.title.isEmpty ? "添加动机" : "编辑动机")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("取消") { dismiss() }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            do { try wall.save(draft, jpeg: jpeg); dismiss() }
                            catch { errorText = error.localizedDescription }
                        }.disabled(!canSave)
                    }
                }
                .task(id: selectedPhoto) {
                    guard let selectedPhoto else { return }
                    let revision = UUID()
                    imageRevision = revision
                    isLoading = true
                    errorText = nil
                    defer { if imageRevision == revision { isLoading = false } }
                    do {
                        guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                            throw MotivationError.invalidImage
                        }
                        let result = try await Task.detached(priority: .userInitiated) {
                            try MotivationStore.preparePhoto(data)
                        }.value
                        try Task.checkCancellation()
                        guard imageRevision == revision else { return }
                        jpeg = result
                    } catch is CancellationError {
                        // Closing the editor cancels its pending import.
                    } catch {
                        guard imageRevision == revision else { return }
                        errorText = "图片读取失败：\(error.localizedDescription)"
                    }
                }
        }
    }
}

struct MotivationManager: View {
    @EnvironmentObject private var wall: MotivationStore
    @Environment(\.dismiss) private var dismiss
    @State private var pendingDelete: MotivationCard?
    @State private var errorText: String?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(wall.cards) { card in
                        HStack(spacing: 14) {
                            if let image = wall.image(for: card) {
                                Image(uiImage: image).resizable().scaledToFill()
                                    .frame(width: 52, height: 64).clipped().clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            VStack(alignment: .leading, spacing: 5) {
                                Text(card.title).font(.headline)
                                Text(card.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }.swipeActions {
                            Button("删除", role: .destructive) { pendingDelete = card }
                        }
                    }.onMove { offsets, destination in
                        do { try wall.move(from: offsets, to: destination) }
                        catch { errorText = error.localizedDescription }
                    }.onDelete { offsets in
                        // Confirmation is shown before the persisted card is removed.
                        if let first = offsets.first { pendingDelete = wall.cards[first] }
                    }
                } footer: { Text("点击“编辑”，拖动右侧手柄调整顺序；左滑删除卡片。") }
            }.navigationTitle("管理动机墙").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) { EditButton().labelStyle(.titleOnly) }
                    ToolbarItem(placement: .navigationBarTrailing) { Button("完成") { dismiss() } }
                }
                .confirmationDialog("删除这张动机卡片？", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }), titleVisibility: .visible) {
                    Button("删除", role: .destructive) {
                        if let card = pendingDelete {
                            do { try wall.delete(card) } catch { errorText = error.localizedDescription }
                        }
                        pendingDelete = nil
                    }
                }
                .alert("保存失败", isPresented: Binding(get: { errorText != nil }, set: { if !$0 { errorText = nil } })) {
                    Button("好", role: .cancel) { errorText = nil }
                } message: { Text(errorText ?? "") }
        }
    }
}
