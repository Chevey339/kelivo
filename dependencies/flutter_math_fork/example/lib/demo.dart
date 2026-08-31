import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:provider/provider.dart';

class DemoPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 800),
          child: ChangeNotifierProvider(
            create: (context) => TextEditingController(),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Consumer<TextEditingController>(
                    builder: (context, controller, _) => TextField(
                      controller: controller,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Input TeX equation here',
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Center(
                          child: Text(
                            "Flutter Math's output",
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(width: 1),
                              borderRadius: BorderRadius.circular(5.0),
                            ),
                            alignment: Alignment.topCenter,
                            padding: EdgeInsets.all(10),
                            child: Consumer<TextEditingController>(
                              builder: (context, controller, _) =>
                                  SelectableMath.tex(
                                controller.value.text,
                                textStyle: TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
