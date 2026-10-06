import SwiftUI
import PDFKit
import MessageUI

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
struct PDFPreview: UIViewRepresentable {
    let url: URL
    func makeUIView(context: Context) -> PDFView { let view = PDFView(); view.autoScales = true; view.document = PDFDocument(url: url); return view }
    func updateUIView(_ view: PDFView, context: Context) { if view.document?.documentURL != url { view.document = PDFDocument(url: url) } }
}
struct MailDraft: UIViewControllerRepresentable {
    let url: URL
    let data: Data
    let recipients: [String]
    let report: Report
    var finished: (String?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(finished) }
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController(); controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject("Montagebericht – \(report.customer) – Auftrag \(report.order)")
        controller.setMessageBody("Guten Tag,\n\nanbei erhalten Sie den Bericht zu Auftrag \(report.order).", isHTML: false)
        controller.addAttachmentData(data, mimeType: "application/pdf", fileName: url.lastPathComponent)
        return controller
    }
    func updateUIViewController(_ controller: MFMailComposeViewController, context: Context) {}
    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let finished: (String?) -> Void
        init(_ finished: @escaping (String?) -> Void) { self.finished = finished }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) { finished(error?.localizedDescription) }
    }
}
