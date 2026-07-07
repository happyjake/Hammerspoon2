//
//  UIWebViewContainer.swift
//  Hammerspoon 2
//

import SwiftUI
import WebKit
import _WebKit_SwiftUI

// MARK: - View Configuration

/// Configuration passed from HSUIWebView to UIWebViewContainer at show() time.
@available(macOS 26.0, *)
struct UIWebViewConfiguration {
    var showToolbar: Bool
    var allowsBackForwardGestures: Bool
    var allowsMagnificationGestures: Bool
    var allowsLinkPreviews: Bool
    var showsContentBackground: Bool
}

// MARK: - Root Container

/// SwiftUI root view hosting a WebView with optional toolbar.
@available(macOS 26.0, *)
struct UIWebViewContainer: View {
    let page: WebPage
    let configuration: UIWebViewConfiguration

    var body: some View {
        VStack(spacing: 0) {
            if configuration.showToolbar {
                UIWebViewToolbar(page: page)
                Divider()
            }
            WebView(page)
                .webViewBackForwardNavigationGestures(
                    configuration.allowsBackForwardGestures ? .enabled : .disabled
                )
                .webViewMagnificationGestures(
                    configuration.allowsMagnificationGestures ? .enabled : .disabled
                )
                .webViewLinkPreviews(
                    configuration.allowsLinkPreviews ? .enabled : .disabled
                )
                .webViewContentBackground(
                    configuration.showsContentBackground ? .visible : .hidden
                )
        }
    }
}

// MARK: - Toolbar

/// Navigation toolbar shown above the web view when enabled.
@available(macOS 26.0, *)
private struct UIWebViewToolbar: View {
    let page: WebPage

    @State private var urlText: String = ""
    @FocusState private var urlFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                Button {
                    if let item = page.backForwardList.backList.last {
                        _ = page.load(item)
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(page.backForwardList.backList.isEmpty)
                .help("Go Back")
                .accessibilityLabel("Go Back")

                Button {
                    if let item = page.backForwardList.forwardList.first {
                        _ = page.load(item)
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .disabled(page.backForwardList.forwardList.isEmpty)
                .help("Go Forward")
                .accessibilityLabel("Go Forward")

                Button {
                    if page.isLoading { page.stopLoading() }
                    else { _ = page.reload() }
                } label: {
                    Image(systemName: page.isLoading ? "xmark" : "arrow.clockwise")
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.borderless)
                .help(page.isLoading ? "Stop Loading" : "Reload Page")
                .accessibilityLabel(page.isLoading ? "Stop Loading" : "Reload Page")

                TextField("Enter URL", text: $urlText)
                    .textFieldStyle(.roundedBorder)
                    .focused($urlFieldFocused)
                    .onSubmit { navigateToURLText() }
                    .onChange(of: page.url) { _, newURL in
                        if !urlFieldFocused {
                            urlText = newURL?.absoluteString ?? ""
                        }
                    }
                    .onAppear {
                        urlText = page.url?.absoluteString ?? ""
                    }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            if page.isLoading {
                ProgressView(value: page.estimatedProgress)
                    .progressViewStyle(.linear)
                    .frame(height: 2)
                    .animation(.linear(duration: 0.15), value: page.estimatedProgress)
            }
        }
    }

    private func navigateToURLText() {
        let trimmed = urlText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let urlString = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        if let url = URL(string: urlString) {
            _ = page.load(url)
        }
    }
}
