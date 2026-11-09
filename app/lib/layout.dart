import 'package:flutter/widgets.dart';

/// The widest the content gets. A phone screen is narrower than this and uses all of it; on a tablet the content stays a phone-sized
/// column in the middle (lines stay short, the buttons stay together), and the rest of the screen is empty.
const double maxContentWidth = 600;

/// Horizontal padding for a scrolling screen: [min] on a phone, more on a wide screen so the content is centred in at most [maxContentWidth].
/// Padding (instead of a narrow box) keeps the whole width scrollable.
double sidePadding(BuildContext context, {double min = 16}) {
  final width = MediaQuery.sizeOf(context).width;
  return width > maxContentWidth + 2 * min ? (width - maxContentWidth) / 2 : min;
}
