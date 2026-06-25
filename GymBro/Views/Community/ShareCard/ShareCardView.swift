//
//  ShareCardView.swift
//  GymBro
//
//  9:16 share card — used as carousel slide #1 in the feed, as the live
//  preview in the editor, and rasterized to PNG for Stories / WhatsApp / Save.
//

import SwiftUI

struct ShareCardView: View {
    let config: ShareConfig
    let workout: WorkoutSnapshot
    // When set, used instead of CachedAsyncImage for the photo background.
    // ImageRenderer is synchronous and can't wait on async image loads, so the
    // rasterizer pre-fetches the photo and passes the UIImage in here.
    var prerenderedBackground: UIImage? = nil

    var body: some View {
        GeometryReader { geo in
            // Scale all internal sizing off the card's width so the same
            // view renders sharp at any frame size (editor preview = 220pt,
            // feed card ~ 360pt, ImageRenderer = 1080pt).
            let s = geo.size.width / 360.0
            let palette = palette(for: config.background)

            // Content drives the card's box. The background (photo + scrim
            // gradient) is applied via .background() so it's clipped to the
            // content's exact bounds — the image can no longer push the
            // ZStack out of the 9:16 frame set below.
            VStack(alignment: .leading, spacing: 14 * s) {
                header(scale: s, palette: palette)
                titleBlock(scale: s, palette: palette)
                if !visibleStats.isEmpty {
                    statsRow(scale: s, palette: palette)
                }
                if !visibleExercises.isEmpty {
                    exerciseList(scale: s, palette: palette)
                }
                Spacer(minLength: 0)
                footer(scale: s, palette: palette)
            }
            .padding(.horizontal, 22 * s)
            .padding(.top, 22 * s)
            .padding(.bottom, 20 * s)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background {
                ZStack {
                    // Opaque white base so low-opacity gradient stops (e.g.
                    // the paper preset's 6%-opacity purple) compose against
                    // white. Without this, ImageRenderer (which uses a black
                    // canvas) bleeds dark through the transparent parts,
                    // making rasterized cards look totally different from
                    // the in-app preview.
                    Color.white
                    if let prerendered = prerenderedBackground {
                        Image(uiImage: prerendered)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let url = config.background.photoURL {
                        CachedAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gymBroNeutral100
                        } failure: {
                            Color.gymBroNeutral100
                        }
                    }
                    config.background.gradient
                }
            }
            .clipped()
        }
        .aspectRatio(9.0 / 16.0, contentMode: .fit)
    }

    // MARK: Sections

    private func header(scale s: CGFloat, palette: Palette) -> some View {
        HStack(spacing: 6 * s) {
            Image("AppLogo")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: 22 * s, height: 22 * s)
                .clipShape(RoundedRectangle(cornerRadius: 5 * s))
            Text("GYMJAM")
                .font(.system(size: 10 * s, weight: .heavy))
                .tracking(0.9 * s)
                .foregroundColor(palette.secondary)
        }
    }

    private func titleBlock(scale s: CGFloat, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            if let cat = config.category?.uppercased(), !cat.isEmpty {
                Text(cat)
                    .font(.system(size: 11 * s, weight: .heavy))
                    .tracking(1.3 * s)
                    .foregroundColor(Color.gymBroPrimary)
            }
            Text(config.title)
                .font(.system(size: 26 * s, weight: .heavy))
                .foregroundColor(palette.title)
                .tracking(-0.6 * s)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }

    private func statsRow(scale s: CGFloat, palette: Palette) -> some View {
        // Cramming 5-6 columns into one row truncates the longer labels
        // ("CALORIES", "AVG HR") and visually jams everything together. Wrap to
        // a second row when there are enough stats that the grid breathes.
        let cols: Int = {
            switch visibleStats.count {
            case 0...3: return max(visibleStats.count, 1)
            case 4:     return 2
            default:    return 3
            }
        }()
        let rows = stride(from: 0, to: visibleStats.count, by: cols).map {
            Array(visibleStats[$0..<min($0 + cols, visibleStats.count)])
        }
        return VStack(alignment: .leading, spacing: 14 * s) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.offset) { idx, stat in
                        statColumn(stat, scale: s, palette: palette)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if idx < row.count - 1 {
                            Spacer(minLength: 4 * s)
                        }
                    }
                    // Keep the last row left-aligned when it's short of `cols`.
                    // maxHeight:0 prevents Color.clear from pulling the HStack
                    // to fill vertically (which made the tile balloon).
                    if row.count < cols {
                        ForEach(0..<(cols - row.count), id: \.self) { _ in
                            Color.clear
                                .frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
        }
        .padding(12 * s)
        .background(
            ZStack {
                Color.white.opacity(palette.statsTileWhiteOpacity)
                LinearGradient(
                    colors: [Color(hex: "7A82F6").opacity(0.10), Color.clear],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12 * s))
        .overlay(
            RoundedRectangle(cornerRadius: 12 * s)
                .stroke(palette.divider, lineWidth: 1)
        )
    }

    private func statColumn(_ stat: StatKey, scale s: CGFloat, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 2 * s) {
            Text(stat.shortLabel)
                .font(.system(size: 8 * s, weight: .heavy))
                .tracking(0.7 * s)
                .foregroundColor(palette.statLabel)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .fixedSize(horizontal: false, vertical: true)
            Text(workout.value(for: stat))
                .font(.system(size: 18 * s, weight: .heavy))
                .foregroundColor(palette.title)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private func exerciseList(scale s: CGFloat, palette: Palette) -> some View {
        VStack(alignment: .leading, spacing: 4 * s) {
            ForEach(Array(visibleExercises.enumerated()), id: \.offset) { idx, ex in
                exerciseRow(ex, index: idx, scale: s, palette: palette)
            }
        }
    }

    private func exerciseRow(_ ex: WorkoutSnapshotExercise, index: Int, scale s: CGFloat, palette: Palette) -> some View {
        let accent = Color(hex: ex.accentColorHex)
        return HStack(spacing: 8 * s) {
            // Index chip
            ZStack {
                RoundedRectangle(cornerRadius: 4 * s)
                    .fill(accent.opacity(0.12))
                Text("\(index + 1)")
                    .font(.system(size: 9 * s, weight: .heavy))
                    .foregroundColor(accent)
            }
            .frame(width: 18 * s, height: 18 * s)

            Text(ex.name)
                .font(.system(size: 12 * s, weight: .heavy))
                .foregroundColor(palette.title)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 4 * s)

            HStack(spacing: 6 * s) {
                if !ex.setChips.isEmpty {
                    Text("^[\(ex.setChips.count) set](inflect: true)")
                        .font(.system(size: 9 * s, weight: .heavy))
                        .foregroundColor(palette.statLabel)
                        .monospacedDigit()
                    Rectangle()
                        .fill(palette.divider)
                        .frame(width: 1, height: 10 * s)
                }
                Text(ex.bestSetLine)
                    .font(.system(size: 11 * s, weight: .heavy))
                    .foregroundColor(palette.title)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 8 * s)
        .padding(.vertical, 6 * s)
        .background(Color.white.opacity(palette.rowWhiteOpacity))
        .clipShape(RoundedRectangle(cornerRadius: 8 * s))
        .overlay(
            RoundedRectangle(cornerRadius: 8 * s)
                .stroke(palette.divider, lineWidth: 1)
        )
    }

    private func footer(scale s: CGFloat, palette: Palette) -> some View {
        HStack(spacing: 6 * s) {
            if let handle = workout.authorHandle, !handle.isEmpty {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.gymBroPrimary, Color(hex: "D65D68")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 16 * s, height: 16 * s)
                    .overlay(
                        Text(String(handle.first ?? "·").uppercased())
                            .font(.system(size: 8 * s, weight: .heavy))
                            .foregroundColor(.white)
                    )
                Text("@\(handle)")
                    .font(.system(size: 9 * s, weight: .heavy))
                    .foregroundColor(palette.title)
            }
            Spacer()
            Text("gyymjaam.com")
                .font(.system(size: 9 * s, weight: .semibold))
                .foregroundColor(palette.secondary.opacity(0.85))
        }
    }

    // MARK: Filters

    /// Stats appear in StatKey.allCases order, filtered by selection + value availability.
    private var visibleStats: [StatKey] {
        StatKey.allCases.filter { config.selectedStatKeys.contains($0) }
    }

    /// Cap at 8 — fits comfortably inside the 9:16 frame; beyond that rows
    /// start eating into the footer.
    private var visibleExercises: [WorkoutSnapshotExercise] {
        workout.exercises
            .filter { config.selectedExerciseIds.contains($0.id) }
            .prefix(8)
            .map { $0 }
    }

    // MARK: Palette

    private struct Palette {
        let title: Color
        let secondary: Color
        let statLabel: Color
        let divider: Color
        let statsTileWhiteOpacity: Double
        let rowWhiteOpacity: Double
    }

    private func palette(for bg: ShareBackground) -> Palette {
        if bg.prefersDarkContent {
            return Palette(
                title: Color.gymBroNeutral900,
                secondary: Color.gymBroTextSecondary,
                statLabel: Color.gymBroTextSecondary,
                divider: Color(hex: "ECECF0"),
                statsTileWhiteOpacity: 1.0,
                rowWhiteOpacity: 1.0
            )
        }
        return Palette(
            title: .white,
            secondary: Color.white.opacity(0.78),
            statLabel: Color.white.opacity(0.7),
            divider: Color.white.opacity(0.18),
            statsTileWhiteOpacity: 0.10,
            rowWhiteOpacity: 0.10
        )
    }
}
