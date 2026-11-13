import 'package:material_ui/material_ui.dart';

enum GameLayoutClass { phone, tablet, desktop }

class GameLayoutSpec {
  const GameLayoutSpec({
    required this.layoutClass,
    required this.columns,
    required this.padding,
    required this.spacing,
  });

  static const tabletBreakpoint = 600.0;
  static const desktopBreakpoint = 1024.0;

  final GameLayoutClass layoutClass;
  final int columns;
  final double padding;
  final double spacing;

  static GameLayoutSpec resolve(
    double width,
    int playerCount, {
    double? height,
  }) {
    if (width >= desktopBreakpoint) {
      return GameLayoutSpec(
        layoutClass: GameLayoutClass.desktop,
        columns: playerCount,
        padding: 20,
        spacing: 16,
      );
    }
    if (width >= tabletBreakpoint) {
      return GameLayoutSpec(
        layoutClass: GameLayoutClass.tablet,
        columns: height != null && width > height
            ? playerCount
            : playerCount.clamp(1, 3),
        padding: 16,
        spacing: 14,
      );
    }
    return GameLayoutSpec(
      layoutClass: GameLayoutClass.phone,
      columns: 1,
      padding: 10,
      spacing: 10,
    );
  }

  double itemWidth(double availableWidth) =>
      (availableWidth - spacing * (columns - 1)) / columns;
}

class GameLayoutMarker extends StatelessWidget {
  const GameLayoutMarker({
    required this.layoutClass,
    required this.child,
    super.key,
  });

  final GameLayoutClass layoutClass;
  final Widget child;

  @override
  Widget build(BuildContext context) => KeyedSubtree(
    key: ValueKey('game-layout-${layoutClass.name}'),
    child: child,
  );
}

class ZoomableGameDisplay extends StatefulWidget {
  const ZoomableGameDisplay({required this.child, super.key});

  final Widget child;

  @override
  State<ZoomableGameDisplay> createState() => _ZoomableGameDisplayState();
}

class _ZoomableGameDisplayState extends State<ZoomableGameDisplay> {
  static const _minScale = 0.75;
  static const _maxScale = 2.0;
  static const _scaleStep = 0.25;

  final TransformationController _controller = TransformationController();
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateScale);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateScale)
      ..dispose();
    super.dispose();
  }

  void _updateScale() {
    final scale = _controller.value.getMaxScaleOnAxis();
    if (scale != _scale) {
      setState(() => _scale = scale);
    }
  }

  void _setScale(double scale) {
    final nextScale = scale.clamp(_minScale, _maxScale);
    _controller.value = Matrix4.diagonal3Values(
      nextScale,
      nextScale,
      nextScale,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          key: const ValueKey('game-display-zoom-view'),
          transformationController: _controller,
          minScale: _minScale,
          maxScale: _maxScale,
          boundaryMargin: const EdgeInsets.all(80),
          child: widget.child,
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            borderRadius: BorderRadius.circular(4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('game-display-zoom-in'),
                  tooltip: 'Zoom in',
                  onPressed: _scale < _maxScale
                      ? () => _setScale(_scale + _scaleStep)
                      : null,
                  icon: const Icon(Icons.add),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                ),
                IconButton(
                  key: const ValueKey('game-display-zoom-reset'),
                  tooltip: 'Reset zoom',
                  onPressed: _scale == 1 ? null : () => _setScale(1),
                  icon: const Icon(Icons.center_focus_strong),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                ),
                IconButton(
                  key: const ValueKey('game-display-zoom-out'),
                  tooltip: 'Zoom out',
                  onPressed: _scale > _minScale
                      ? () => _setScale(_scale - _scaleStep)
                      : null,
                  icon: const Icon(Icons.remove),
                  color: Colors.white,
                  disabledColor: Colors.white38,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
