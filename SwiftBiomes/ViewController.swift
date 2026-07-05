//
//  ViewController.swift
//  SwiftBiomes
//
//  Created by Christopher Lloyd on 2026.07.05.
//

import Cocoa

final class ViewController: NSViewController, NSToolbarDelegate {
    private let mainController = MainSplitViewController()

    override func viewDidLoad() {
        super.viewDidLoad()

        addChild(mainController)
        mainController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainController.view)

        NSLayoutConstraint.activate([
            mainController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainController.view.topAnchor.constraint(equalTo: view.topAnchor),
            mainController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        configureWindow()
    }

    private func configureWindow() {
        guard let window = view.window else {
            return
        }

        window.title = ""
        window.minSize = NSSize(width: 900, height: 560)
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        window.toolbarStyle = .unified

        if window.toolbar == nil {
            let toolbar = NSToolbar(identifier: "SwiftBiomesToolbar")
            toolbar.delegate = self
            toolbar.displayMode = .iconOnly
            toolbar.allowsUserCustomization = false
            window.toolbar = toolbar
        }
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, .locateOrigin, .zoomOut, .zoomIn, .refreshMap, .flexibleSpace, .queryFocus]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.sidebarTrackingSeparator, .locateOrigin, .zoomOut, .zoomIn, .refreshMap, .flexibleSpace, .queryFocus]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case .locateOrigin:
            return toolbarItem(identifier: itemIdentifier, label: "Origin", symbolName: "scope", action: #selector(centerOnOrigin))
        case .zoomOut:
            return toolbarItem(identifier: itemIdentifier, label: "Zoom Out", symbolName: "minus.magnifyingglass", action: #selector(zoomOut))
        case .zoomIn:
            return toolbarItem(identifier: itemIdentifier, label: "Zoom In", symbolName: "plus.magnifyingglass", action: #selector(zoomIn))
        case .refreshMap:
            return toolbarItem(identifier: itemIdentifier, label: "Refresh", symbolName: "arrow.clockwise", action: #selector(refresh))
        case .queryFocus:
            return toolbarItem(identifier: itemIdentifier, label: "Query", symbolName: "text.magnifyingglass", action: #selector(focusQuery))
        default:
            return nil
        }
    }

    private func toolbarItem(identifier: NSToolbarItem.Identifier, label: String, symbolName: String, action: Selector) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: label)
        item.target = self
        item.action = action
        return item
    }

    @objc private func centerOnOrigin() {
        mainController.centerOnOrigin()
    }

    @objc private func zoomOut() {
        mainController.zoomOut()
    }

    @objc private func zoomIn() {
        mainController.zoomIn()
    }

    @objc private func refresh() {
        mainController.refresh()
    }

    @objc private func focusQuery() {
        mainController.focusQuery()
    }
}

private extension NSToolbarItem.Identifier {
    static let locateOrigin = NSToolbarItem.Identifier("SwiftBiomesLocateOrigin")
    static let zoomOut = NSToolbarItem.Identifier("SwiftBiomesZoomOut")
    static let zoomIn = NSToolbarItem.Identifier("SwiftBiomesZoomIn")
    static let refreshMap = NSToolbarItem.Identifier("SwiftBiomesRefreshMap")
    static let queryFocus = NSToolbarItem.Identifier("SwiftBiomesQueryFocus")
}
