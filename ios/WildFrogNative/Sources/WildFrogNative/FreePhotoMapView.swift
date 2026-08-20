import MapKit
import Photos
import SwiftUI
import UIKit

private final class FreePhotoMapAnnotation: NSObject, MKAnnotation {
    let record: FreePhotoRecord
    dynamic var coordinate: CLLocationCoordinate2D

    init(record: FreePhotoRecord) {
        self.record = record
        let coordinate = record.coordinate ?? FreePhotoCoordinate(latitude: 0, longitude: 0)
        self.coordinate = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var title: String? { record.placeName }
}

private final class FreePhotoAnnotationView: MKAnnotationView {
    private let photoView = UIImageView()
    private let countLabel = UILabel()
    private let pointer = UIView()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 68, height: 76)
        centerOffset = CGPoint(x: 0, y: -34)
        collisionMode = .rectangle
        canShowCallout = false

        pointer.frame = CGRect(x: 28, y: 53, width: 14, height: 14)
        pointer.backgroundColor = .white
        pointer.transform = CGAffineTransform(rotationAngle: .pi / 4)
        pointer.layer.cornerRadius = 2
        addSubview(pointer)

        photoView.frame = CGRect(x: 5, y: 2, width: 58, height: 58)
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = 12
        photoView.layer.borderWidth = 3
        photoView.layer.borderColor = UIColor.white.cgColor
        photoView.layer.shadowColor = UIColor.black.cgColor
        photoView.layer.shadowOpacity = 0.24
        photoView.layer.shadowRadius = 5
        photoView.layer.shadowOffset = CGSize(width: 0, height: 3)
        addSubview(photoView)

        countLabel.frame = CGRect(x: 43, y: 0, width: 25, height: 25)
        countLabel.backgroundColor = UIColor(red: 0.05, green: 0.16, blue: 0.30, alpha: 1)
        countLabel.textColor = .white
        countLabel.font = .systemFont(ofSize: 12, weight: .bold)
        countLabel.textAlignment = .center
        countLabel.layer.cornerRadius = 12.5
        countLabel.clipsToBounds = true
        countLabel.layer.borderWidth = 2
        countLabel.layer.borderColor = UIColor.white.cgColor
        addSubview(countLabel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(image: UIImage?, count: Int?) {
        photoView.image = image ?? UIImage(systemName: "photo.fill")
        photoView.backgroundColor = UIColor(red: 0.80, green: 0.90, blue: 0.94, alpha: 1)
        photoView.tintColor = UIColor(red: 0.05, green: 0.16, blue: 0.30, alpha: 1)
        if let count, count > 1 {
            countLabel.text = "\(count)"
            countLabel.isHidden = false
        } else {
            countLabel.isHidden = true
        }
    }
}

struct FreePhotoMapView: UIViewRepresentable {
    let records: [FreePhotoRecord]
    let thumbnailURL: (FreePhotoRecord) -> URL
    let mapType: MKMapType
    let onSelect: ([FreePhotoRecord]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsUserLocation = true
        map.pointOfInterestFilter = .excludingAll
        map.register(
            FreePhotoAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "free-photo"
        )
        map.register(
            FreePhotoAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: "free-photo-cluster"
        )
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.mapType = mapType
        let existing = map.annotations.compactMap { $0 as? FreePhotoMapAnnotation }
        let incomingIDs = Set(records.map(\.id))
        let existingIDs = Set(existing.map(\.record.id))
        if incomingIDs != existingIDs {
            map.removeAnnotations(existing)
            map.addAnnotations(records.filter(\.hasValidCoordinate).map(FreePhotoMapAnnotation.init))
        }
        if !context.coordinator.didFitRecords, !records.isEmpty {
            context.coordinator.didFitRecords = true
            map.showAnnotations(
                map.annotations.filter { !($0 is MKUserLocation) },
                animated: false
            )
        }
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: FreePhotoMapView
        var didFitRecords = false

        init(parent: FreePhotoMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(
                    withIdentifier: "free-photo-cluster",
                    for: cluster
                ) as! FreePhotoAnnotationView
                view.clusteringIdentifier = nil
                let records = cluster.memberAnnotations
                    .compactMap { ($0 as? FreePhotoMapAnnotation)?.record }
                    .sorted { $0.createdAt > $1.createdAt }
                view.configure(
                    image: records.first.flatMap(loadThumbnail),
                    count: records.count
                )
                view.isAccessibilityElement = true
                view.accessibilityTraits = .button
                view.accessibilityLabel = AppText.value(
                    zh: "\(records.count) 張自由拍相片",
                    en: "\(records.count) Free Photos"
                )
                return view
            }

            guard let photoAnnotation = annotation as? FreePhotoMapAnnotation else { return nil }
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: "free-photo",
                for: photoAnnotation
            ) as! FreePhotoAnnotationView
            view.clusteringIdentifier = "free-photo"
            view.configure(image: loadThumbnail(photoAnnotation.record), count: nil)
            view.isAccessibilityElement = true
            view.accessibilityTraits = .button
            view.accessibilityLabel = photoAnnotation.record.placeName
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let cluster = view.annotation as? MKClusterAnnotation {
                let records = cluster.memberAnnotations
                    .compactMap { ($0 as? FreePhotoMapAnnotation)?.record }
                    .sorted { $0.createdAt > $1.createdAt }
                parent.onSelect(records)
            } else if let annotation = view.annotation as? FreePhotoMapAnnotation {
                parent.onSelect([annotation.record])
            }
            mapView.deselectAnnotation(view.annotation, animated: false)
        }

        private func loadThumbnail(_ record: FreePhotoRecord) -> UIImage? {
            UIImage(contentsOfFile: parent.thumbnailURL(record).path)
        }
    }
}

struct FreePhotoMapDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: FreePhotoStore

    let records: [FreePhotoRecord]
    let onEditLocation: (FreePhotoRecord) -> Void

    @State private var pendingDelete: FreePhotoRecord?
    @State private var showDeleteChoices = false
    @State private var deleteError: String?
    @State private var isDeleting = false
    @State private var deletionCoordinator = FreePhotoDeletionCoordinator()

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(records.filter { record in
                        store.records.contains(where: { $0.id == record.id })
                    }) { record in
                        recordCard(record)
                    }
                }
                .padding()
            }
            .background(FreePhotoPalette.paleMist)
            .navigationTitle(records.count > 1
                ? AppText.value(zh: "\(records.count) 張自由拍", en: "\(records.count) Free Photos")
                : AppText.value(zh: "自由拍位置", en: "Free Photo Location"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(AppText.value(zh: "完成", en: "Done")) { dismiss() }
                }
            }
            .overlay {
                if isDeleting {
                    ProgressView()
                        .padding(22)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .alert(
                AppText.value(zh: "未能刪除", en: "Could Not Delete"),
                isPresented: Binding(
                    get: { deleteError != nil },
                    set: { if !$0 { deleteError = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(deleteError ?? "")
            }
            .confirmationDialog(
                AppText.value(zh: "刪除自由拍", en: "Delete Free Photo"),
                isPresented: $showDeleteChoices,
                titleVisibility: .visible
            ) {
                Button(
                    AppText.value(zh: "只刪除地圖紀錄", en: "Delete Map Record"),
                    role: .destructive
                ) {
                    deleteRecordOnly()
                }
                if pendingDelete?.photosAssetIdentifier != nil {
                    Button(
                        AppText.value(zh: "刪除地圖紀錄及相框相片", en: "Delete Map Record and Framed Photo"),
                        role: .destructive
                    ) {
                        deleteRecordAndPhoto()
                    }
                }
                Button(AppText.value(zh: "取消", en: "Cancel"), role: .cancel) {}
            } message: {
                Text(AppText.value(
                    zh: "原本由相簿揀入嚟嘅相片永遠唔會被刪除。",
                    en: "The original photo you imported is never deleted."
                ))
            }
        }
    }

    private func recordCard(_ record: FreePhotoRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Group {
                if let image = UIImage(contentsOfFile: store.thumbnailURL(for: record).path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ZStack {
                        FreePhotoPalette.mist
                        Image(systemName: "photo.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(FreePhotoPalette.navy.opacity(0.55))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 210)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(record.placeName)
                .font(.frogTitle)
                .foregroundStyle(FreePhotoPalette.navy)

            HStack(spacing: 12) {
                Label(record.createdAt.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                if let altitude = record.altitudeMetres {
                    Label("\(altitude)m", systemImage: "mountain.2")
                }
            }
            .font(.frogCaption)
            .foregroundStyle(FreePhotoPalette.navy.opacity(0.7))

            Label(record.locationSource.localizedLabel, systemImage: "location.fill")
                .font(.frogCaption.weight(.semibold))
                .foregroundStyle(FreePhotoPalette.blue)

            HStack {
                if record.photosAssetIdentifier != nil {
                    Button {
                        if let url = URL(string: "photos-redirect://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label(AppText.value(zh: "在相簿開啟", en: "Open Photos"), systemImage: "photo.on.rectangle")
                    }
                }
                Button {
                    dismiss()
                    onEditLocation(record)
                } label: {
                    Label(AppText.value(zh: "修改位置", en: "Edit Location"), systemImage: "mappin.and.ellipse")
                }
                Spacer()
                Button(role: .destructive) {
                    pendingDelete = record
                    showDeleteChoices = true
                } label: {
                    Image(systemName: "trash")
                }
            }
            .font(.frogCaption.weight(.bold))
        }
        .padding(14)
        .background(.white, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func deleteRecordOnly() {
        guard let pendingDelete else { return }
        performDelete(record: pendingDelete, mode: .recordOnly)
    }

    private func deleteRecordAndPhoto() {
        guard let pendingDelete else { return }
        performDelete(record: pendingDelete, mode: .recordAndFramedPhoto)
    }

    private func performDelete(record: FreePhotoRecord, mode: FreePhotoDeletionMode) {
        isDeleting = true
        Task {
            let outcome = await deletionCoordinator.delete(
                record: record,
                mode: mode,
                photos: PhotoLibrarySaver(),
                records: store
            )
            isDeleting = false
            switch outcome {
            case .completed:
                pendingDelete = nil
                if store.records.isEmpty { dismiss() }
            case .assetNotFound:
                deleteError = AppText.value(
                    zh: "相簿已經搵唔到呢張相框相片；你仍可選擇只刪除地圖紀錄。",
                    en: "The framed photo is no longer in Photos. You can still delete the map record only."
                )
            case .photosFailed:
                deleteError = AppText.value(
                    zh: "相框相片未被刪除，地圖紀錄亦已保留。",
                    en: "The framed photo was not deleted, so the map record was preserved."
                )
            case .recordFailed:
                deleteError = AppText.value(
                    zh: "相片已處理，但未能刪除本機地圖紀錄。",
                    en: "The photo action completed, but the local map record could not be removed."
                )
            case .missingPhotosIdentifier:
                deleteError = AppText.value(
                    zh: "搵唔到相框相片資料；你仍可選擇只刪除地圖紀錄。",
                    en: "The framed photo reference is unavailable. You can still delete the map record only."
                )
            }
        }
    }
}

struct FreePhotoManualLocationPicker: View {
    @Environment(\.dismiss) private var dismiss

    let record: FreePhotoRecord
    let onSave: (FreePhotoCoordinate) -> Void

    @State private var position: MapCameraPosition
    @State private var center: CLLocationCoordinate2D

    init(record: FreePhotoRecord, onSave: @escaping (FreePhotoCoordinate) -> Void) {
        self.record = record
        self.onSave = onSave
        let initial = record.coordinate.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        } ?? CLLocationCoordinate2D(latitude: 22.34, longitude: 114.16)
        _center = State(initialValue: initial)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: initial,
            span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
        )))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position)
                    .mapStyle(.standard)
                    .onMapCameraChange(frequency: .continuous) { context in
                        center = context.region.center
                    }
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(FreePhotoPalette.navy)
                    .shadow(color: .white, radius: 3)
                    .offset(y: -20)
            }
            .navigationTitle(AppText.value(zh: "設定自由拍位置", en: "Set Free Photo Location"))
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    onSave(FreePhotoCoordinate(latitude: center.latitude, longitude: center.longitude))
                    dismiss()
                } label: {
                    Text(AppText.value(zh: "儲存呢個位置", en: "Save This Location"))
                        .font(.frogRow.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(FreePhotoPalette.navy, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(AppText.value(zh: "取消", en: "Cancel")) { dismiss() }
                }
            }
        }
    }
}
