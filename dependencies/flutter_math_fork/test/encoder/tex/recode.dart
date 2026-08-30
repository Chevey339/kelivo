import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_math_fork/src/parser/tex/parser.dart';

import 'package:flutter_math_fork/src/encoder/tex/encoder.dart';

String recodeTex(String tex) => TexParser(tex, const TexParserSettings())
    .parse()
    .encodeTeX(conf: TexEncodeConf.mathParamConf);
