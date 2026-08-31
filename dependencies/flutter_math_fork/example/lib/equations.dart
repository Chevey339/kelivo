import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:google_fonts/google_fonts.dart';

const equations = [
  ['Solution of quadratic equation', r'x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}'],
  [
    'Schrodinger\'s equation',
    r'i\hbar\frac{\partial}{\partial t}\Psi(\vec x,t) = -\frac{\hbar}{2m}\nabla^2\Psi(\vec x,t)+ V(\vec x)\Psi(\vec x,t)'
  ],
  [
    'Fourier transform',
    r'\hat f(\xi) = \int_{-\infty}^\infty {f(x)e^{- 2\pi i \xi x}\mathrm{d}x}'
  ],
  [
    'Maxwell\'s equations',
    r'''\left\{\begin{array}{l}
  \nabla\cdot\vec{D} = \rho \\
  \nabla\cdot\vec{B} = 0 \\
  \nabla\times\vec{E} = -\frac{\partial\vec{B}}{\partial t} \\
  \nabla\times\vec{H} = \vec{J}_f + \frac{\partial\vec{D}}{\partial t} 
\end{array}\right.'''
  ],
];

class EquationsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 800),
          child: ListView(
            children: equations
                .map((entry) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text(entry[0]),
                              subtitle: SelectableText(
                                entry[1],
                                style: GoogleFonts.robotoMono(),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.fromLTRB(1, 5, 1, 5),
                              child: SelectableMath.tex(
                                entry[1],
                                textStyle: TextStyle(fontSize: 22),
                              ),
                            )
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      );
}
