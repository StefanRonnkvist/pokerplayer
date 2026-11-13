import 'package:material_ui/material_ui.dart';

/// Responsive controls for the actions available during a betting turn.
class BettingActions extends StatelessWidget {
  const BettingActions({
    required this.keyPrefix,
    required this.enabled,
    required this.canBet,
    required this.canRaise,
    required this.canCall,
    required this.canCheck,
    required this.selectedAction,
    required this.onSelected,
    this.recommendedBet,
    super.key,
  });

  static const _actions = ['Bet', 'Raise', 'Call', 'Check', 'Fold'];
  static const _minimumActionWidth = 52.0;
  static const _actionHeight = 28.0;

  final String keyPrefix;
  final bool enabled;
  final bool canBet;
  final bool canRaise;
  final bool canCall;
  final bool canCheck;
  final String? selectedAction;
  final ValueChanged<String> onSelected;
  final double? recommendedBet;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Fit as many fixed-minimum-width actions as possible, then wrap the
        // remaining buttons into rows without changing their hit-box height.
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _minimumActionWidth * _actions.length;
        final columnCount = (availableWidth / _minimumActionWidth)
            .floor()
            .clamp(1, _actions.length);
        final rowCount = (_actions.length / columnCount).ceil();
        final actionWidth = availableWidth / columnCount;

        final showRecommendation = enabled && recommendedBet != null;
        return SizedBox(
          height: rowCount * _actionHeight + (showRecommendation ? 16 : 0),
          child: Column(
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final action in _actions)
                    SizedBox(
                      width: actionWidth,
                      height: _actionHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Column(
                          children: [
                            SizedBox(
                              height: 20,
                              width: double.infinity,
                              child: OutlinedButton(
                                key: ValueKey(
                                  '$keyPrefix-${action.toLowerCase()}',
                                ),
                                onPressed: _isAvailable(action)
                                    ? () => onSelected(action)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 20),
                                  padding: EdgeInsets.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  foregroundColor: _isSelected(action)
                                      ? Colors.black
                                      : Colors.white,
                                  backgroundColor: _isSelected(action)
                                      ? Colors.amberAccent
                                      : Colors.transparent,
                                  side: BorderSide(
                                    color: _isSelected(action)
                                        ? Colors.amberAccent
                                        : Colors.white70,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0,
                                  ),
                                ),
                                child: Text(action),
                              ),
                            ),
                            if (_isAvailable(action))
                              Icon(
                                Icons.arrow_drop_up,
                                key: ValueKey(
                                  '$keyPrefix-${action.toLowerCase()}-available',
                                ),
                                color: Colors.amberAccent,
                                size: 8,
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              if (showRecommendation)
                SizedBox(
                  height: 16,
                  child: Text(
                    'Recommended bet: \$${recommendedBet!.toStringAsFixed(2)}',
                    key: ValueKey('$keyPrefix-recommended-bet'),
                    style: const TextStyle(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isAvailable(String action) =>
      enabled &&
      switch (action) {
        'Bet' => canBet,
        'Raise' => canRaise,
        'Call' => canCall,
        'Check' => canCheck,
        'Fold' => true,
        _ => false,
      };

  bool _isSelected(String action) => !enabled && selectedAction == action;
}
