import SwiftUI
import AppKit

struct ContainerLogView: View {
    let containerId: String
    @Environment(DockerClient.self) private var client
    @State private var logText: String = ""
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading logs...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error {
                ContentUnavailableView("Failed to Load Logs",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error))
            } else if logText.isEmpty {
                ContentUnavailableView("No Logs",
                    systemImage: "doc.text",
                    description: Text("This container has no log output"))
            } else {
                LogTextView(text: logText)
            }
        }
        .task(id: containerId) {
            await loadLogs()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await loadLogs() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func loadLogs() async {
        isLoading = true
        error = nil
        do {
            logText = try await client.fetchLogs(for: containerId)
            isLoading = false
        } catch {
            self.error = error.localizedDescription
            isLoading = false
        }
    }
}

struct LogTextView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        textView.backgroundColor = NSColor.textBackgroundColor
        textView.textColor = NSColor.textColor
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Disable line wrapping for horizontal scrolling
        textView.isHorizontallyResizable = true
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scrollView.hasHorizontalScroller = true

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let textView = scrollView.documentView as! NSTextView
        let currentText = textView.string

        if currentText != text {
            textView.string = text

            // Scroll to bottom
            textView.scrollToEndOfDocument(nil)
        }
    }
}
