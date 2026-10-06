import SwiftUI

struct ContentView: View {
    @State private var store = UsageStore()
    @State private var showSettings = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            Background()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if let usage = store.usage {
                        content(usage)
                    } else if store.error == nil {
                        ProgressView().tint(Theme.peach).padding(.top, 160)
                    }
                    if let error = store.error {
                        errorCard(error)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .refreshable { await store.refresh(force: true) }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
        .task(id: scenePhase) {
            // Poll while the app is in the foreground.
            guard scenePhase == .active else { return }
            while !Task.isCancelled {
                await store.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
        .sensoryFeedback(.success, trigger: store.usage?.fetchedAt)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Spark()
                .fill(Theme.coral)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text("Claude Usage")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(Theme.cream)
                TimelineView(.periodic(from: .now, by: 10)) { ctx in
                    Text(updatedText(now: ctx.date))
                        .font(.footnote)
                        .foregroundStyle(Theme.secondary)
                        .contentTransition(.numericText())
                }
            }
            Spacer()
            Button {
                Task { await store.refresh(force: true) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .rotationEffect(.degrees(store.isLoading ? 360 : 0))
                    .animation(store.isLoading ? .linear(duration: 0.9).repeatForever(autoreverses: false) : .default,
                               value: store.isLoading)
            }
            .buttonStyle(CircleButton())
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .buttonStyle(CircleButton())
        }
        .padding(.top, 8)
    }

    private func updatedText(now: Date) -> String {
        guard let at = store.usage?.fetchedAt else { return store.isLoading ? "Loading…" : "No data yet" }
        let s = Int(now.timeIntervalSince(at))
        if store.isLoading { return "Refreshing…" }
        if s < 60 { return "Updated just now" }
        return "Updated \(s / 60) min ago"
    }

    @ViewBuilder
    private func content(_ usage: Usage) -> some View {
        let session = usage.session
        if let session {
            hero(session)
        }
        ForEach(LimitGroup.group(usage.limits.filter { $0.id != session?.id })) { group in
            LimitGroupCard(group: group)
        }
        if !usage.insights.isEmpty {
            insights(usage.insights)
        }
    }

    private func hero(_ limit: Usage.Limit) -> some View {
        VStack(spacing: 18) {
            ZStack {
                RingGauge(percent: limit.percent, lineWidth: 24)
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(Int(limit.percent.rounded()))")
                            .font(.system(size: 76, weight: .bold, design: .rounded))
                            .contentTransition(.numericText(value: limit.percent))
                        Text("%")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.secondary)
                    }
                    .foregroundStyle(Theme.cream)
                    Text(limit.label.uppercased())
                        .font(.caption.weight(.semibold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.secondary)
                }
                .animation(.snappy, value: limit.percent)
            }
            .frame(width: 250, height: 250)
            .padding(.top, 18)

            ResetPill(limit: limit)
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }

    private func insights(_ lines: [String]) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("What's using your limits", systemImage: "chart.bar.xaxis")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cream)
                ForEach(Array(lines.enumerated()), id: \.offset) { i, line in
                    HStack(alignment: .top, spacing: 10) {
                        Circle().fill(i == 0 ? Theme.peach : Theme.coral.opacity(0.7))
                            .frame(width: 6, height: 6).padding(.top, 7)
                        Text(line)
                            .font(.subheadline)
                            .foregroundStyle(i == 0 ? Theme.cream : Theme.cream.opacity(0.75))
                    }
                }
                Text("Based on sessions on your Mac")
                    .font(.caption2)
                    .foregroundStyle(Theme.secondary.opacity(0.7))
            }
        }
    }

    private func errorCard(_ error: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Can't reach the Mac", systemImage: "wifi.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(Theme.amber)
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(Theme.secondary)
                Text("Server: \(store.publicURL)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(Theme.secondary)
                Button("Change server") { showSettings = true }
                    .font(.footnote.weight(.semibold))
                    .tint(Theme.peach)
            }
        }
        .padding(.top, store.usage == nil ? 120 : 0)
    }
}

/// Limits that share a period, e.g. "Current week (all models)" and "Current week (Fable)".
struct LimitGroup: Identifiable {
    let title: String
    let rows: [(name: String?, limit: Usage.Limit)]
    var id: String { title }

    static func group(_ limits: [Usage.Limit]) -> [LimitGroup] {
        var order: [String] = []
        var rows: [String: [(String?, Usage.Limit)]] = [:]
        for l in limits {
            let parts = l.label.split(separator: "(", maxSplits: 1)
            let base = parts[0].trimmingCharacters(in: .whitespaces)
            let name = parts.count == 2 ? parts[1].trimmingCharacters(in: CharacterSet(charactersIn: ") ")) : nil
            if rows[base] == nil { order.append(base) }
            rows[base, default: []].append((name.map { $0.prefix(1).uppercased() + $0.dropFirst() }, l))
        }
        return order.map { base in
            let title = base.replacingOccurrences(of: "Current week", with: "This week")
                .replacingOccurrences(of: "Current session", with: "Session")
            return LimitGroup(title: title, rows: rows[base]!)
        }
    }

    /// One shared reset line when all rows reset within the same hour (they often differ by a minute).
    var sharedReset: Usage.Limit? {
        let dates = rows.compactMap(\.limit.resetsAt)
        guard dates.count == rows.count, let lo = dates.min(), let hi = dates.max(),
              hi.timeIntervalSince(lo) < 3600 else { return nil }
        return rows.first { $0.limit.resetsAt == hi }?.limit
    }
}

struct LimitGroupCard: View {
    let group: LimitGroup

    var body: some View {
        let shared = group.sharedReset
        Card {
            VStack(alignment: .leading, spacing: 16) {
                Text(group.title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.secondary)
                ForEach(group.rows, id: \.limit.id) { row in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(row.name ?? group.title)
                                .font(.headline)
                                .foregroundStyle(Theme.cream)
                            Spacer()
                            Text("\(Int(row.limit.percent.rounded()))%")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.tint(for: row.limit.percent))
                                .contentTransition(.numericText(value: row.limit.percent))
                                .animation(.snappy, value: row.limit.percent)
                        }
                        BarGauge(percent: row.limit.percent)
                        if shared == nil {
                            ResetLine(limit: row.limit)
                        }
                    }
                }
                if let shared {
                    Divider().overlay(Color.white.opacity(0.06))
                    ResetLine(limit: shared)
                }
            }
        }
    }
}

struct ResetLine: View {
    let limit: Usage.Limit
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HStack(spacing: 6) {
                Image(systemName: "arrow.counterclockwise")
                if let at = limit.resetsAt {
                    Text("Resets in **\(ResetFormat.countdown(to: at, now: ctx.date))**")
                    Spacer()
                    Text(ResetFormat.moment(at))
                } else {
                    Text("Resets \(limit.resets)")
                }
            }
            .font(.caption)
            .foregroundStyle(Theme.secondary)
        }
    }
}

struct ResetPill: View {
    let limit: Usage.Limit
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            HStack(spacing: 8) {
                Image(systemName: "clock")
                if let at = limit.resetsAt {
                    Text("Resets in **\(ResetFormat.countdown(to: at, now: ctx.date))**")
                    Text("·").foregroundStyle(Theme.secondary)
                    Text(ResetFormat.moment(at)).foregroundStyle(Theme.secondary)
                } else {
                    Text("Resets \(limit.resets)")
                }
            }
            .font(.subheadline)
            .foregroundStyle(Theme.cream)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.card, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.07)))
        }
    }
}

struct CircleButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.cream)
            .frame(width: 40, height: 40)
            .background(Theme.card, in: Circle())
            .overlay(Circle().strokeBorder(.white.opacity(0.08)))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy, value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
