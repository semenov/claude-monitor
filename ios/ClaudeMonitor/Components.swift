import SwiftUI

struct RingGauge: View {
    let percent: Double
    var lineWidth: CGFloat = 22

    @State private var shown: Double = 0

    var body: some View {
        let colors = Theme.gradient(for: percent)
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.004, shown / 100))
                .stroke(
                    AngularGradient(colors: colors + [colors[0]], center: .center,
                                    startAngle: .degrees(0), endAngle: .degrees(360 * max(shown, 1) / 100 + 1)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: colors[0].opacity(0.55), radius: 14)
        }
        .onAppear { animate(to: percent) }
        .onChange(of: percent) { _, new in animate(to: new) }
    }

    private func animate(to value: Double) {
        withAnimation(.spring(response: 1.1, dampingFraction: 0.85)) { shown = min(value, 100) }
    }
}

struct BarGauge: View {
    let percent: Double
    @State private var shown: Double = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule()
                    .fill(LinearGradient(colors: Theme.gradient(for: percent), startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(10, geo.size.width * shown / 100))
                    .shadow(color: Theme.gradient(for: percent)[0].opacity(0.5), radius: 6)
            }
        }
        .frame(height: 10)
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.85).delay(0.15)) { shown = min(percent, 100) } }
        .onChange(of: percent) { _, new in withAnimation(.spring) { shown = min(new, 100) } }
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: .rect(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(.white.opacity(0.07)))
    }
}
