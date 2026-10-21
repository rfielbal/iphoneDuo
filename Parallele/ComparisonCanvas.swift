import SwiftUI
import UIKit

/// Coordinates are attached to the image, never to the display or its current size.
enum ImageGeometry {
    static func rect(image: CGSize, in container: CGSize, zoom: CGFloat = 1, pan: CGSize = .zero) -> CGRect {
        guard image.width > 0, image.height > 0 else { return .zero }
        let fit = min(container.width / image.width, container.height / image.height)
        let size = CGSize(width: image.width * fit * zoom, height: image.height * fit * zoom)
        return CGRect(x: (container.width - size.width) / 2 + pan.width * container.width,
                      y: (container.height - size.height) / 2 + pan.height * container.height,
                      width: size.width, height: size.height)
    }

    static func normalized(_ point: CGPoint, in rect: CGRect) -> CGPoint? {
        guard rect.width > 0, rect.height > 0, rect.contains(point) else { return nil }
        return CGPoint(x: (point.x - rect.minX) / rect.width, y: (point.y - rect.minY) / rect.height)
    }

    /// Pan is a fraction of the actual photo pane, not of the whole display.
    /// An axis with letterboxing stays centered; only real image overflow can pan.
    static func panLimits(image: CGSize, in container: CGSize, zoom: CGFloat) -> CGSize {
        guard container.width > 0, container.height > 0,
              container.width.isFinite, container.height.isFinite,
              image.width > 0, image.height > 0,
              image.width.isFinite, image.height.isFinite, zoom.isFinite else { return .zero }
        let rendered = rect(image: image, in: container, zoom: max(1, zoom))
        return CGSize(
            width: max(0, (rendered.width - container.width) / 2) / container.width,
            height: max(0, (rendered.height - container.height) / 2) / container.height
        )
    }

    static func clampedPan(_ pan: CGSize, limits: CGSize) -> CGSize {
        CGSize(
            width: pan.width.isFinite ? min(limits.width, max(-limits.width, pan.width)) : 0,
            height: pan.height.isFinite ? min(limits.height, max(-limits.height, pan.height)) : 0
        )
    }
}

private struct ImagePaneFramesKey: PreferenceKey {
    static let defaultValue: [ImageSide: CGRect] = [:]

    static func reduce(value: inout [ImageSide: CGRect], nextValue: () -> [ImageSide: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newValue in newValue })
    }
}

struct ComparisonCanvas: View {
    let before: UIImage
    let after: UIImage
    let sideBySide: Bool
    @Binding var split: Double
    @Binding var zoom: Double
    @Binding var pan: CGSize
    let annotations: [ImageAnnotation]
    let topInset: CGFloat
    let trailingInset: CGFloat
    let isPlacing: Bool
    let onPlace: (ImageSide, CGPoint) -> Void
    let onSelect: (ImageAnnotation) -> Void
    @State private var zoomOrigin: Double?
    @State private var panOrigin: CGSize?
    @State private var panViewport: CGSize?
    @State private var paneFrames: [ImageSide: CGRect] = [:]
    @State private var draggingDivider = false

    var body: some View {
        GeometryReader { geometry in
            Group {
                if sideBySide {
                    paired
                } else {
                    ZStack(alignment: .leading) {
                        photo(after, side: .after, showsPins: false).allowsHitTesting(false)
                        photo(before, side: .before, showsPins: false).allowsHitTesting(false)
                            .mask(alignment: .leading) {
                                Rectangle().frame(width: geometry.size.width * split)
                            }
                        pins(image: before, side: .before, size: geometry.size)
                        pins(image: after, side: .after, size: geometry.size)
                        divider(size: geometry.size)
                    }
                    .overlay(alignment: .top) {
                        HStack {
                            imageLabel(.before)
                            Spacer()
                            imageLabel(.after)
                        }
                        .padding(.leading, 16).padding(.trailing, trailingInset + 16)
                        .padding(.top, topInset + 12)
                        .allowsHitTesting(false)
                    }
                }
            }
            .coordinateSpace(name: "comparison")
            .contentShape(Rectangle())
            .simultaneousGesture(SpatialTapGesture().onEnded { value in
                guard isPlacing, !sideBySide else { return }
                let side: ImageSide = value.location.x < geometry.size.width * split ? .before : .after
                let image = side == .before ? before : after
                let rect = ImageGeometry.rect(image: image.size, in: geometry.size, zoom: zoom, pan: pan)
                if let point = ImageGeometry.normalized(value.location, in: rect) { onPlace(side, point) }
            })
            .simultaneousGesture(MagnifyGesture()
                .onChanged { value in
                    if zoomOrigin == nil { zoomOrigin = zoom }
                    zoom = min(4, max(1, (zoomOrigin ?? 1) * value.magnification))
                    if zoom <= 1 { pan = .zero }
                }
                .onEnded { _ in zoomOrigin = nil })
            .simultaneousGesture(DragGesture(minimumDistance: 12, coordinateSpace: .named("comparison"))
                .onChanged { value in
                    guard zoom > 1, !isPlacing, !draggingDivider else { return }
                    if panOrigin == nil {
                        panOrigin = pan
                        // ArrangementView can split horizontally or vertically, and
                        // around the hinge. Read the pane where this drag started.
                        panViewport = sideBySide
                            ? paneFrames.values.first(where: { $0.contains(value.startLocation) })?.size
                            : geometry.size
                    }
                    let viewport = panViewport ?? geometry.size
                    guard viewport.width > 0, viewport.height > 0 else { return }
                    let proposed = CGSize(
                        width: (panOrigin?.width ?? 0) + value.translation.width / viewport.width,
                        height: (panOrigin?.height ?? 0) + value.translation.height / viewport.height
                    )
                    pan = boundedPan(proposed, frames: paneFrames)
                }
                .onEnded { _ in panOrigin = nil; panViewport = nil })
            .onPreferenceChange(ImagePaneFramesKey.self) { frames in
                guard frames != paneFrames else { return }
                paneFrames = frames
                constrainPan(frames: frames)
                panOrigin = nil
                panViewport = nil
            }
            .onChange(of: zoom) { _, _ in constrainPan(frames: paneFrames) }
            .onChange(of: sideBySide) { _, _ in
                panOrigin = nil
                panViewport = nil
                draggingDivider = false
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("comparisonCanvas")
    }

    @ViewBuilder private var paired: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                photo(before, side: .before, showsPins: true)
            } secondary: {
                photo(after, side: .after, showsPins: true)
            }
            .arrangementViewStyle(.split)
        } else {
            HStack(spacing: 2) {
                photo(before, side: .before, showsPins: true)
                photo(after, side: .after, showsPins: true)
            }
        }
    }

    private func photo(_ image: UIImage, side: ImageSide, showsPins: Bool) -> some View {
        GeometryReader { proxy in
            let rect = ImageGeometry.rect(image: image.size, in: proxy.size, zoom: zoom, pan: pan)
            ZStack(alignment: .topLeading) {
                // A quiet extension of the photo fills letterboxing without cropping the comparison.
                Image(uiImage: image).resizable().scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .blur(radius: 45).opacity(0.22).clipped()
                Image(uiImage: image).resizable()
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .accessibilityHidden(true)
                if showsPins {
                    pins(image: image, side: side, size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .onTapGesture { location in
                guard sideBySide, isPlacing, let normalized = ImageGeometry.normalized(location, in: rect) else { return }
                onPlace(side, normalized)
            }
            .overlay(alignment: side == .before ? .topLeading : .topTrailing) {
                if sideBySide {
                    imageLabel(side)
                        .padding(.leading, 16)
                        .padding(.trailing, side == .after ? trailingInset + 16 : 16)
                        .padding(.top, max(0, topInset - proxy.frame(in: .named("comparison")).minY) + 12)
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .preference(key: ImagePaneFramesKey.self, value: [side: proxy.frame(in: .named("comparison"))])
        }
    }

    private func boundedPan(_ proposed: CGSize, frames: [ImageSide: CGRect]) -> CGSize {
        let limits = [(ImageSide.before, before), (.after, after)].compactMap { side, image -> CGSize? in
            guard let frame = frames[side], frame.width > 0, frame.height > 0 else { return nil }
            return ImageGeometry.panLimits(image: image.size, in: frame.size, zoom: zoom)
        }
        guard let first = limits.first else { return .zero }
        // Shared movement must be safe for both photos, even with different ratios.
        let common = limits.dropFirst().reduce(first) { result, next in
            CGSize(width: min(result.width, next.width), height: min(result.height, next.height))
        }
        return ImageGeometry.clampedPan(proposed, limits: common)
    }

    private func constrainPan(frames: [ImageSide: CGRect]) {
        guard !frames.isEmpty else { return }
        let constrained = boundedPan(pan, frames: frames)
        if constrained != pan { pan = constrained }
    }

    private func imageLabel(_ side: ImageSide) -> some View {
        HStack(spacing: 7) {
            Text(side == .before ? "A" : "B").fontWeight(.bold)
            Text(side == .before ? "Original" : "Retouche")
        }
        .font(.caption).padding(.horizontal, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }

    private func pins(image: UIImage, side: ImageSide, size: CGSize) -> some View {
        let rect = ImageGeometry.rect(image: image.size, in: size, zoom: zoom, pan: pan)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(annotations.enumerated()), id: \.element.id) { index, note in
                let positionX = rect.minX + rect.width * note.x
                let visible = side == .before ? positionX < size.width * split : positionX >= size.width * split
                if note.side == side && (sideBySide || visible) {
                    Button { onSelect(note) } label: {
                        Text("\(index + 1)").font(.system(.callout, design: .rounded, weight: .bold))
                            .foregroundStyle(.white).frame(width: 32, height: 32)
                            .background(.blue, in: Circle())
                            .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 2))
                            .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    }
                    .position(x: positionX, y: rect.minY + rect.height * note.y)
                    .accessibilityLabel("Repère \(index + 1), \(note.text)")
                    .accessibilityIdentifier("annotationPin-\(index)")
                    .disabled(isPlacing)
                }
            }
        }
        .frame(width: size.width, height: size.height)
    }

    private func divider(size: CGSize) -> some View {
        ZStack {
            Rectangle().fill(.white.opacity(0.85)).frame(width: 1.5)
            Image(systemName: "arrow.left.and.right")
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 46, height: 46)
                .glassEffect(.regular.interactive(), in: Circle())
        }
        .frame(width: 50, height: size.height)
        .contentShape(Rectangle())
        .position(x: size.width * split, y: size.height / 2)
        .highPriorityGesture(DragGesture(minimumDistance: 0, coordinateSpace: .named("comparison"))
            .onChanged { value in
                draggingDivider = true
                split = min(0.98, max(0.02, value.location.x / size.width))
            }
            .onEnded { _ in draggingDivider = false; panOrigin = nil; panViewport = nil })
        .accessibilityElement()
        .accessibilityLabel("Position de comparaison")
        .accessibilityValue("\(Int(split * 100)) pour cent")
        .accessibilityAdjustableAction { direction in
            split = min(0.98, max(0.02, split + (direction == .increment ? 0.1 : -0.1)))
        }
        .accessibilityIdentifier("comparisonDivider")
        .allowsHitTesting(!isPlacing)
    }
}
