import AppKit

final class MainSplitViewController: NSSplitViewController {
    private let viewModel = BiomeQueryViewModel()
    private let sidebarController = SidebarViewController()
    private let inspectorController = InspectorViewController()
    private let mapController = NSViewController()
    private let mapView = BiomeMapView()

    override func viewDidLoad() {
        super.viewDidLoad()
        configureMap()
        configureSplitView()
        configureBindings()
        viewModel.submitQuery()
    }

    func centerOnOrigin() {
        mapView.centerOnOrigin()
    }

    func zoomIn() {
        mapView.zoomIn()
    }

    func zoomOut() {
        mapView.zoomOut()
    }

    func refresh() {
        mapView.reloadMap()
        viewModel.submitQuery()
    }

    func focusQuery() {
        sidebarController.focusCoordinateFields()
    }

    private func configureMap() {
        mapView.settings = viewModel.settings
        mapView.translatesAutoresizingMaskIntoConstraints = false

        if #available(macOS 26.0, *) {
            let backgroundView = MapBackgroundExtensionView()
            backgroundView.automaticallyPlacesContentView = false
            backgroundView.contentView = mapView
            backgroundView.translatesAutoresizingMaskIntoConstraints = false
            mapController.view = backgroundView

            NSLayoutConstraint.activate([
                mapView.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
                mapView.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
                mapView.topAnchor.constraint(equalTo: backgroundView.topAnchor),
                mapView.bottomAnchor.constraint(equalTo: backgroundView.bottomAnchor)
            ])
        } else {
            mapController.view = mapView
        }
    }

    private func configureSplitView() {
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.minimumThickness = 220
        sidebarItem.maximumThickness = 280

        let mapItem = NSSplitViewItem(viewController: mapController)
        mapItem.minimumThickness = 360
        if #available(macOS 26.0, *) {
            mapItem.automaticallyAdjustsSafeAreaInsets = true
        }

        let inspectorItem = NSSplitViewItem(inspectorWithViewController: inspectorController)
        inspectorItem.minimumThickness = 240
        inspectorItem.maximumThickness = 320

        addSplitViewItem(sidebarItem)
        addSplitViewItem(mapItem)
        addSplitViewItem(inspectorItem)
    }

    private func configureBindings() {
        viewModel.onChange = { [weak self] viewModel in
            self?.inspectorController.update(state: viewModel.state)
        }

        sidebarController.onQueryRequested = { [weak self] seed, x, z, versionIndex, dimensionIndex in
            guard let self else {
                return
            }

            do {
                try self.viewModel.apply(
                    seedText: seed,
                    xText: x,
                    zText: z,
                    versionIndex: versionIndex,
                    dimensionIndex: dimensionIndex
                )
                self.mapView.settings = self.viewModel.settings
                self.viewModel.submitQuery()
            } catch let error as BiomeQueryViewModel.QueryError {
                self.inspectorController.update(state: .failed(error.message))
            } catch {
                self.inspectorController.update(state: .failed("Unable to apply query settings."))
            }
        }

        sidebarController.onOverlayChanged = { [weak self] enabled in
            self?.mapView.overlayEnabled = enabled
        }

        mapView.onCoordinateSelected = { [weak self] x, z in
            guard let self else {
                return
            }

            self.sidebarController.setCoordinate(x: x, z: z)
            self.viewModel.x = x
            self.viewModel.z = z
            self.viewModel.submitQuery()
        }
    }
}

@available(macOS 26.0, *)
private final class MapBackgroundExtensionView: NSBackgroundExtensionView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard
            let contentView,
            !contentView.isHidden,
            contentView.alphaValue > 0
        else {
            return super.hitTest(point)
        }

        let contentPoint = contentView.convert(point, from: self)
        guard contentView.bounds.contains(contentPoint) else {
            return super.hitTest(point)
        }

        return contentView.hitTest(contentPoint) ?? contentView
    }
}
