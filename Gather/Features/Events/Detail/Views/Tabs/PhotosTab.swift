import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Photos Tab

struct PhotosTab: View {
    let event: Event
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var photos: [MediaItem]

    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var selectedItem: MediaItem?
    @State private var showPhotoViewer = false
    @State private var isLoadingPhoto = false
    @State private var loadingProgress = ""
    @State private var showPhotoError = false
    @State private var photoErrorMessage = ""

    init(event: Event) {
        self.event = event
        let eventId = event.id
        let imageRawValue = MediaType.image.rawValue
        _photos = Query(
            filter: #Predicate<MediaItem> { $0.eventId == eventId && $0.type.rawValue == imageRawValue },
            sort: \MediaItem.createdAt,
            order: .reverse
        )
    }

    private var isHost: Bool {
        event.hostId == authManager.currentUser?.id
    }

    private let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                // Upload bar
                uploadBar

                if photos.isEmpty {
                    emptyState
                } else {
                    // Photo count
                    HStack {
                        Text("\(photos.count) \(photos.count == 1 ? "photo" : "photos")")
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.md)

                    // Photo grid
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(photos) { item in
                            photoCell(item)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
            .padding(.vertical, Spacing.sm)
        }
        .fullScreenCover(isPresented: $showPhotoViewer) {
            if let item = selectedItem {
                PhotoViewerView(
                    mediaItem: item,
                    allPhotos: photos,
                    isHost: isHost,
                    onDelete: { deletePhoto(item) }
                )
            }
        }
        .onChange(of: selectedPhotos) { _, newItems in
            guard !newItems.isEmpty else { return }
            isLoadingPhoto = true
            let total = newItems.count
            loadingProgress = "Processing 1/\(total) photos..."
            Task {
                defer {
                    Task { @MainActor in
                        isLoadingPhoto = false
                        selectedPhotos = []
                    }
                }
                var failedCount = 0
                for (index, item) in newItems.enumerated() {
                    await MainActor.run {
                        loadingProgress = "Processing \(index + 1)/\(total) photos..."
                    }
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else {
                            failedCount += 1
                            continue
                        }
                        let compressed = await Task.detached {
                            guard let uiImage = UIImage(data: data) else { return nil as Data? }
                            let maxDimension: CGFloat = 2048
                            let scale = min(maxDimension / max(uiImage.size.width, uiImage.size.height), 1.0)
                            let newSize = CGSize(width: uiImage.size.width * scale, height: uiImage.size.height * scale)
                            let renderer = UIGraphicsImageRenderer(size: newSize)
                            let resized = renderer.image { _ in
                                uiImage.draw(in: CGRect(origin: .zero, size: newSize))
                            }
                            return resized.jpegData(compressionQuality: 0.7)
                        }.value

                        if let compressed {
                            await MainActor.run {
                                addPhoto(imageData: compressed)
                            }
                        } else {
                            failedCount += 1
                        }
                    } catch {
                        failedCount += 1
                    }
                }
                if failedCount > 0 {
                    await MainActor.run {
                        photoErrorMessage = "\(failedCount) of \(total) photos could not be processed."
                        showPhotoError = true
                    }
                }
            }
        }
        .alert("Photo Error", isPresented: $showPhotoError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(photoErrorMessage)
        }
        .overlay {
            if isLoadingPhoto {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .overlay {
                        VStack(spacing: Spacing.sm) {
                            ProgressView()
                            Text(loadingProgress)
                                .font(GatherFont.callout)
                        }
                        .padding(Spacing.lg)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.md))
                    }
            }
        }
    }

    // MARK: - Upload Bar

    private var uploadBar: some View {
        PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 20, matching: .images) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentPurpleFallback)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Photos")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Select up to 20 photos at once")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.gatherSecondaryText)
            }
            .padding(Spacing.md)
            .background(Color.gatherSecondaryBackground.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.lg))
        }
        .padding(.horizontal, Spacing.md)
    }

    // MARK: - Photo Cell

    private func photoCell(_ item: MediaItem) -> some View {
        Button {
            selectedItem = item
            showPhotoViewer = true
        } label: {
            ZStack(alignment: .bottom) {
                Group {
                    if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let url = item.url {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gatherSecondaryBackground
                        }
                    } else {
                        Color.gatherSecondaryBackground
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.gatherSecondaryText)
                            )
                    }
                }
                .frame(minHeight: 120)
                .clipped()

                // Caption overlay
                if let caption = item.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48))
                .foregroundStyle(Color.gatherSecondaryText.opacity(0.5))

            Text("No photos yet")
                .font(GatherFont.headline)
                .foregroundStyle(Color.gatherSecondaryText)

            Text("Tap above to add the first photo")
                .font(GatherFont.callout)
                .foregroundStyle(Color.gatherTertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xxl)
    }

    // MARK: - Helpers

    private func addPhoto(imageData: Data) {
        let item = MediaItem(
            imageData: imageData,
            eventId: event.id,
            uploaderId: authManager.currentUser?.id,
            uploaderName: authManager.currentUser?.name ?? "Guest"
        )
        modelContext.insert(item)
        modelContext.safeSave()

        HapticService.success()
    }

    private func deletePhoto(_ item: MediaItem) {
        modelContext.delete(item)
        modelContext.safeSave()
        showPhotoViewer = false
        selectedItem = nil
    }
}

// MARK: - Photo Viewer

struct PhotoViewerView: View {
    let mediaItem: MediaItem
    let allPhotos: [MediaItem]
    let isHost: Bool
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var currentIndex: Int = 0
    @State private var showInfo = false
    @State private var showDeleteConfirmation = false
    @State private var editingCaption = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                TabView(selection: $currentIndex) {
                    ForEach(Array(allPhotos.enumerated()), id: \.element.id) { index, photo in
                        photoView(photo)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: Spacing.md) {
                        Button {
                            showInfo.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.white.opacity(0.8))
                        }

                        if isHost {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showInfo) {
                photoInfoSheet
            }
            .confirmationDialog("Delete Photo?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    onDelete()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This photo will be permanently removed.")
            }
        }
        .onAppear {
            if let idx = allPhotos.firstIndex(where: { $0.id == mediaItem.id }) {
                currentIndex = idx
            }
        }
    }

    @ViewBuilder
    private func photoView(_ photo: MediaItem) -> some View {
        if let imageData = photo.imageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else if let url = photo.url {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } placeholder: {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    private var currentPhoto: MediaItem {
        currentIndex < allPhotos.count ? allPhotos[currentIndex] : mediaItem
    }

    private var photoInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                let photo = currentPhoto

                HStack {
                    Circle()
                        .fill(Color.gatherSecondaryBackground)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(photo.uploaderName.prefix(1)))
                                .font(GatherFont.callout)
                                .fontWeight(.bold)
                        )

                    VStack(alignment: .leading) {
                        Text(photo.uploaderName)
                            .font(GatherFont.headline)
                        Text(photo.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(GatherFont.caption)
                            .foregroundStyle(Color.gatherSecondaryText)
                    }
                }

                // Editable caption
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Caption")
                        .font(GatherFont.caption)
                        .foregroundStyle(Color.gatherSecondaryText)

                    TextField("Add a caption...", text: $editingCaption, axis: .vertical)
                        .font(GatherFont.body)
                        .lineLimit(3)
                        .padding(Spacing.sm)
                        .background(Color.gatherSecondaryBackground.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.sm))
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Photo Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveCaption()
                        showInfo = false
                    }
                }
            }
            .onAppear {
                editingCaption = currentPhoto.caption ?? ""
            }
        }
        .presentationDetents([.medium])
    }

    private func saveCaption() {
        let photo = currentPhoto
        let trimmed = editingCaption.trimmingCharacters(in: .whitespacesAndNewlines)
        photo.caption = trimmed.isEmpty ? nil : trimmed
        modelContext.safeSave()
    }
}
