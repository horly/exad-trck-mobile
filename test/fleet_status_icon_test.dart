import 'package:exad_tracking_mobile/shared/widgets/fleet_status_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders four compact vector icons on one narrow row', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 240,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: FleetStatusIcon(
                      symbol: FleetStatusSymbol.online,
                      color: Colors.green,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FleetStatusIcon(
                      symbol: FleetStatusSymbol.offline,
                      color: Colors.red,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FleetStatusIcon(
                      symbol: FleetStatusSymbol.moving,
                      color: Colors.purple,
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: FleetStatusIcon(
                      symbol: FleetStatusSymbol.parked,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final icons = find.byType(FleetStatusIcon);
    expect(icons, findsNWidgets(4));
    for (var index = 0; index < 4; index++) {
      expect(tester.getSize(icons.at(index)), const Size.square(28));
      expect(
        tester.getTopLeft(icons.at(index)).dy,
        tester.getTopLeft(icons.first).dy,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
