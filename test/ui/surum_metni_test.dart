import 'package:butce_takip/surum.dart';
import 'package:butce_takip/ui_metin.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  uiTest('Ayarlar altında sürüm metni görünür (derleme numarası olmadan)', (
    t,
  ) async {
    telefonBoyutu(t);
    await uygulamaAc(t, await bellekDb(t));
    await t.tap(find.text(sekmeAyarlar).first);
    await bekle(t);
    expect(
      find.text('Bütçe Takip ${uygulamaSurumu.split('+').first}'),
      findsOneWidget,
    );
    expect(find.text('Bütçe Takip 0.3.1'), findsOneWidget);
  });
}
