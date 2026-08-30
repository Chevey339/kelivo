import 'package:flutter_test/flutter_test.dart';

import 'helper.dart';
import 'load_fonts.dart';

void main() {
  setUpAll(loadKaTeXFonts);

  testTexToMatchGoldenFile(
    'Solution of quadratic equation',
    r'x=\frac{-b\pm\sqrt{b^2-4ac}}{2a}',
    location: '../doc/img/delta.png',
    scale: 5,
  );
  testTexToMatchGoldenFile(
    'Schrodinger equation',
    r'i\hbar\frac{\partial}{\partial t}\Psi(\vec x,t) = -\frac{\hbar}{2m}\nabla^2\Psi(\vec x,t)+V(\vec x)\Psi(\vec x,t)',
    location: '../doc/img/schrodinger.png',
    scale: 5,
  );
  testTexToMatchGoldenFile(
    'Fourier transform',
    r'\hat f(\xi) = \int_{-\infty}^{+\infty}{f(x)e^{-2\pi i \xi x}\mathrm{d}x}',
    location: '../doc/img/fourier.png',
    scale: 5,
  );
}
