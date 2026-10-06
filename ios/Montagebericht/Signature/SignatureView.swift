import SwiftUI
import PencilKit

struct SignatureCanvas: UIViewRepresentable {
    @Binding var data: Data?
    var locked: Bool
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.tool = PKInkingTool(.pen, color: UIColor(red: 0.08, green: 0.20, blue: 0.32, alpha: 1), width: 3)
        canvas.backgroundColor = .white; canvas.isOpaque = true
        canvas.isScrollEnabled = false
        canvas.overrideUserInterfaceStyle = .light
        return canvas
    }
    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        canvas.isUserInteractionEnabled = !locked
        let current = canvas.drawing.strokes.isEmpty ? nil : canvas.drawing.dataRepresentation()
        if current != data {
            context.coordinator.updating = true
            canvas.drawing = data.flatMap { try? PKDrawing(data: $0) } ?? PKDrawing()
            context.coordinator.updating = false
        }
    }
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignatureCanvas
        var updating = false
        init(_ parent: SignatureCanvas) { self.parent = parent }
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            guard !updating, !parent.locked else { return }
            parent.data = canvasView.drawing.strokes.isEmpty ? nil : canvasView.drawing.dataRepresentation()
        }
    }
}

struct SignatureSection: View {
    let title: String
    @Binding var data: Data?
    let locked: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                if !locked { Button("Löschen", role: .destructive) { data = nil }.frame(minHeight: 44) }
            }
            SignatureCanvas(data: $data, locked: locked)
                .frame(height: 180).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary))
                .accessibilityLabel(title + ". Mit Finger oder Apple Pencil zeichnen.")
            Text(data == nil ? "Noch keine Unterschrift erfasst" : "Unterschrift erfasst").font(.caption).foregroundStyle(.secondary)
        }
    }
}
