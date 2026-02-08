import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Photos Tab

struct PhotosTab: View {
    let event: Event
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.modelContext) private var modelContext
    @Query private var allMediaItems: [MediaItem]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedItem: MediaItem?
    @State private var showPhotoViewer = false

    private var photos: [MediaItem] {
        allMediaItems
            .filter { $0.eventId == event.id && $0.type == .image }
            .sorted { $0.createdAt > $1.createdAt }
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
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    addPhoto(imageData: data)
                    selectedPhoto = nil
                }
            }
        }
    }

    // MARK: - Upload Bar

    private var uploadBar: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(Color.accentPurpleFallback)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Add Photos")
                        .font(GatherFont.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.gatherPrimaryText)

                    Text("Share your event memories")
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
        try? modelContext.save()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func deletePhoto(_ item: MediaItem) {
        modelContext.delete(item)
        try? modelContext.save()
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
    @State private var currentIndex: Int = 0
    @State private var showInfo = false

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
                                onDelete()
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

    private var photoInfoSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: Spacing.md) {
                let photo = currentIndex < allPhotos.count ? allPhotos[currentIndex] : mediaItem

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

                if let caption = photo.caption, !caption.isEmpty {
                    Text(caption)
                        .font(GatherFont.body)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Photo Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showInfo = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
