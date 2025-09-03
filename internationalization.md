---
# title: Internationalizing Flutter apps
title: Flutter 应用里的国际化
short-title: i18n
# description: How to internationalize your Flutter app.
description: 如何实现 Flutter 应用程序的国际化。
tags: Flutter开发
keywords: 国际化
---

<?code-excerpt path-base="internationalization"?>

{% comment %}
Consider updating the number of languages when touching this page.
{% endcomment %}

{% assign languageCount = '115' -%}

:::secondary 你将学习到
<!-- What you'll learn -->

* How to track the device's locale (the user's preferred language).

  如何去获取设备的语言环境（用户首选的语言）。
* How to enable locale-specific Material or Cupertino widgets.

  如何去管理特定语言环境下的 Material 或 Cupertino widget。

* How to manage locale-specific app values.

  如何去管理特定语言环境下的 app 值。

* How to define the locales an app supports.

  如何去定义 app 支持的语言环境。

:::

If your app might be deployed to users who speak another
language then you'll need to internationalize it.
That means you need to write the app in a way that makes
it possible to localize values like text and layouts
for each language or locale that the app supports.
Flutter provides widgets and classes that help with
internationalization and the Flutter libraries
themselves are internationalized.

如果你的 app 会部署给说其他语言的用户使用，那么你就需要对它进行国际化。
这就意味着你在编写 app 的时候，需要采用一种容易对它进行本地化的方式进行开发，
这种方式让你能够为每一种语言或者 app 所支持的语言环境下的文本和布局等进行本地化。
Flutter 提供了 widgets 和类来帮助开发者进行国际化，
当然 Flutter 库本身就是国际化的。

This page covers concepts and workflows necessary to
localize a Flutter application using the
`MaterialApp` and `CupertinoApp` classes,
as most apps are written that way.
However, applications written using the lower level
`WidgetsApp` class can also be internationalized
using the same classes and logic.

由于大多数应用程序都是以这种方式编写的，
因此该页面主要介绍了使用 `MaterialApp` 和 `CupertinoApp`
对 Flutter 应用程序进行本地化所需的概念和工作流程。
但是，使用较低级别的 `WidgetsApp` 类编写的应用程序
也可以使用相同的类和逻辑进行国际化。

## Introduction to localizations in Flutter

## Flutter 应用本地化介绍

This section provides a tutorial on how to create and
internationalize a new Flutter application,
along with any additional setup
that a target platform might require.

本节主要介绍如何对 Flutter 应用进行国际化，以及针对目标平台需要设置的其他内容。

You can find the source code for this example in
[`gen_l10n_example`][].

你可以在 [`gen_l10n_example`][] 仓库找到源代码。

[`gen_l10n_example`]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/gen_l10n_example

### Setting up an internation&shy;alized app: the Flutter<wbr>_localizations package {:#setting-up}

### 配置一个国际化的 app：flutter_localizations package

By default, Flutter only provides US English localizations.
To add support for other languages,
an application must specify additional
`MaterialApp` (or `CupertinoApp`) properties,
and include a package called `flutter_localizations`.
As of December 2023, this package supports [{{languageCount}} languages][language-count]
and language variants.

默认情况下，Flutter 只提供美式英语的本地化。
如果想要添加其他语言，你的应用必须指定额外的
`MaterialApp` 或者 `CupertinoApp` 属性并且
添加一个名为 `flutter_localizations` 的 package。
截至到 2023 年 12 月份，这个 package 已经支持 [{{languageCount}} 种语言][language-count]。

To begin, start by creating a new Flutter application
in a directory of your choice with the `flutter create` command.

若要开始使用，在 Flutter 工程文件夹下执行 `flutter create` 命令:

```console
$ flutter create <name_of_flutter_app>
```

To use `flutter_localizations`,
add the package as a dependency to your `pubspec.yaml` file, 
as well as the `intl` package:

想要使用 `flutter_localizations` 的话，
你需要在 `pubspec.yaml` 文件中添加它和 `intl` 作为依赖：

```console
$ flutter pub add flutter_localizations --sdk=flutter
$ flutter pub add intl:any
```

This creates a `pubspec.yml` file with the following entries:

最终的 `pubspec.yaml` 文件中形如：

<?code-excerpt "gen_l10n_example/pubspec.yaml (flutter-localizations)"?>
```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: any
```

Then import the `flutter_localizations` library and specify
`localizationsDelegates` and `supportedLocales` for
your `MaterialApp` or `CupertinoApp`:

下一步，先运行 `pub get packages`，然后引入 flutter_localizations 库，
然后为 MaterialApp 指定 `localizationsDelegates` 和 `supportedLocales`：

<?code-excerpt "gen_l10n_example/lib/main.dart (localization-delegates-import)"?>
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
```

<?code-excerpt "gen_l10n_example/lib/main.dart (material-app)" remove="AppLocalizations.delegate"?>
```dart
return const MaterialApp(
  title: 'Localizations Sample App',
  localizationsDelegates: [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: [
    Locale('en'), // English
    Locale('es'), // Spanish
  ],
  home: MyHomePage(),
);
```

After introducing the `flutter_localizations` package
and adding the previous code,
the `Material` and `Cupertino`
packages should now be correctly localized in
one of the {{languageCount}} supported locales.
Widgets should be adapted to the localized messages,
along with correct left-to-right or right-to-left layout.

引入 `flutter_localizations` package 并添加了上面的代码之后，
`Material` 和 `Cupertino` 包现在应该被正确地本地化为 {{languageCount}} 个受支持的语言环境之一。
widget 应当与本地化信息保持同步，并具有正确的从左到右或从右到左的布局。 

Try switching the target platform's locale to
Spanish (`es`) and the messages should be localized.

你可以尝试将目标平台的语言环境切换为西班牙语 (`es`)，
然后应该可以发现信息已经被本地化了。

Apps based on `WidgetsApp` are similar except that the
`GlobalMaterialLocalizations.delegate` isn't needed.

基于 `WidgetsApp` 构建的 app 在添加语言环境时，
除了 `GlobalMaterialLocalizations.delegate` 不需要之外，
其他的操作是类似的。

The full `Locale.fromSubtags` constructor is preferred
as it supports [`scriptCode`][], though the `Locale` default
constructor is still fully valid.

虽然 `语言环境 (Locale)` 默认的构造函数是完全没有问题的，
但是还是建议大家使用 `Locale.fromSubtags` 的构造函数，
因为它支持设置 [文字代码][`scriptCode`]。

[`scriptCode`]: {{site.api}}/flutter/package-intl_locale/Locale/scriptCode.html

The elements of the `localizationsDelegates` list are
factories that produce collections of localized values.
`GlobalMaterialLocalizations.delegate` provides localized
strings and other values for the Material Components
library. `GlobalWidgetsLocalizations.delegate`
defines the default text direction,
either left-to-right or right-to-left, for the widgets library.

`localizationDelegates` 数组是用于生成本地化值集合的工厂。
`GlobalMaterialLocalizations.delegate` 为 Material 组件库
提供本地化的字符串和一些其他的值。
`GlobalWidgetsLocalizations.delegate` 为 widgets 库
定义了默认的文本排列方向，由左到右或者由右到左。

More information about these app properties, the types they
depend on, and how internationalized Flutter apps are typically
structured, is covered in this page.

想知道更多关于这些 app 属性，
它们依赖的类型以及那些国际化的 Flutter app 通常是如何组织的，
可以继续阅读下面内容。

[language-count]: {{site.api}}/flutter/flutter_localizations/GlobalMaterialLocalizations-class.html

<a id="overriding-locale"></a>
### Overriding the locale

### 重载语言

`Localizations.override` is a factory constructor
for the `Localizations` widget that allows for
(the typically rare) situation where a section of your application
needs to be localized to a different locale than the locale
configured for your device. 

`Localizations.override` 提供了一个工厂构造方法，
使得你可以从在某一个位置设置与应用不同的语言（非一般情况）。

To observe this behavior, add a call to `Localizations.override`
and a simple `CalendarDatePicker`:

下面的示例展示了 `Localizations.override` 与 `CalendarDatePicker` 组合使用的情况：

<?code-excerpt "gen_l10n_example/lib/examples.dart (date-picker)"?>
```dart
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Add the following code
          Localizations.override(
            context: context,
            locale: const Locale('es'),
            // Using a Builder to get the correct BuildContext.
            // Alternatively, you can create a new widget and Localizations.override
            // will pass the updated BuildContext to the new widget.
            child: Builder(
              builder: (context) {
                // A toy example for an internationalized Material widget.
                return CalendarDatePicker(
                  initialDate: DateTime.now(),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2100),
                  onDateChanged: (value) {},
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
```

Hot reload the app and the `CalendarDatePicker`
widget should re-render in Spanish.

应用热重载后，你将能够发现 `CalendarDatePicker` widget 显示为西班牙语了。

<a id="adding-localized-messages"></a>
### Adding your own localized messages

### 添加你自己的本地化信息

After adding the `flutter_localizations` package,
you can configure localization.
To add localized text to your application,
complete the following instructions:

引入 `flutter_localizations` package 后，
请按照以下说明将本地化的文本添加到你的应用。

1. Add the `intl` package as a dependency, pulling
   in the version pinned by `flutter_localizations`:

   将 `intl` package 添加为依赖，
   使用 `any` 作为 `flutter_localizations` 的版本值:

   ```console
   $ flutter pub add intl:any
   ```

2. Open the `pubspec.yaml` file and enable the `generate` flag. 
   This flag is found in the `flutter` section in the pubspec file.

   另外，在 `pubspec.yaml` 文件中，启用 `generate` 标志。
   该设置项添加在 pubspec 中 Flutter 部分，
   通常处在 pubspec 文件中后面的部分。

   <?code-excerpt "gen_l10n_example/pubspec.yaml (generate)"?>
   ```yaml
   # The following section is specific to Flutter.
   flutter:
     generate: true # Add this line
   ```

3. Add a new yaml file to the root directory of the Flutter project.
   Name this file `l10n.yaml` and include following content:

   在 Flutter 项目的根目录中添加一个新的 yaml 文件，
   命名为 `l10n.yaml`，其内容如下：

   <?code-excerpt "gen_l10n_example/l10n.yaml"?>
   ```yaml
   arb-dir: lib/l10n
   template-arb-file: app_en.arb
   output-localization-file: app_localizations.dart
   ```

   This file configures the localization tool.
   In this example, you've done the following:

   该文件用于配置本地化工具。它为你的项目配置了如下内容：

   * Put the [App Resource Bundle][] (`.arb`) input files in
     `${FLUTTER_PROJECT}/lib/l10n`.

     将 [应用资源包][App Resource Bundle] (`.arb`)
     的输入路径指定为 `${FLUTTER_PROJECT}/lib/l10n`。

     The `.arb` provide localization resources for your app. 

     `.arb` 文件提供了应用的本地化资源。

   * Set the English template as `app_en.arb`.

     将英文的语言模板设定为 `app_en.arb`。

   * Told Flutter to generate localizations in the
     `app_localizations.dart` file.

     指定 Flutter 生成本地化内容到 `app_localizations.dart` 文件。

4. In `${FLUTTER_PROJECT}/lib/l10n`,
   add the `app_en.arb` template file. For example:

   在 `${FLUTTER_PROJECT}/lib/l10n` 中，添加 `app_en.arb` 模板文件。如下：

   <?code-excerpt "gen_l10n_example/lib/l10n/app_en.arb" take="5" replace="/},/}\n}/g"?>
   ```json
   {
     "helloWorld": "Hello World!",
     "@helloWorld": {
       "description": "The conventional newborn programmer greeting"
     }
   }
   ```

5. Add another bundle file called `app_es.arb` in the same directory.
   In this file, add the Spanish translation of the same message.

   接下来，在同一目录中添加一个 `app_es.arb` 文件，
   对同一条信息做西班牙语的翻译：

   <?code-excerpt "gen_l10n_example/lib/l10n/app_es.arb"?>
   ```json
   {
       "helloWorld": "¡Hola Mundo!"
   }
   ```

6. Now, run `flutter pub get` or `flutter run` and codegen takes place automatically.
   You should find generated files in the directory at the path you specified
   with the `arb-dir` or `output-dir` options
   Alternatively, you can also run `flutter gen-l10n` to
   generate the same files without running the app.

   现在，运行 `flutter run` 命令，
   你能在 `arb-dir` 或 `output-dir` 选项指定的路径下看到生成的文件。
   同样的，你可以在应用没有运行的时候运行
   `flutter gen-l10n` 来生成本地化文件。

7. Add the import statement on `app_localizations.dart` and
   `AppLocalizations.delegate`
   in your call to the constructor for `MaterialApp`:

   在调用 `MaterialApp` 的构造函数时候，添加 `import` 语句，导入
   `app_localizations.dart` 和 `AppLocalizations.delegate`。

   <?code-excerpt "gen_l10n_example/lib/main.dart (app-localizations-import)"?>
   ```dart
   import 'l10n/app_localizations.dart';
   ```

   <?code-excerpt "gen_l10n_example/lib/main.dart (material-app)"?>
   ```dart
   return const MaterialApp(
     title: 'Localizations Sample App',
     localizationsDelegates: [
       AppLocalizations.delegate, // Add this line
       GlobalMaterialLocalizations.delegate,
       GlobalWidgetsLocalizations.delegate,
       GlobalCupertinoLocalizations.delegate,
     ],
     supportedLocales: [
       Locale('en'), // English
       Locale('es'), // Spanish
     ],
     home: MyHomePage(),
   );
   ```

   The `AppLocalizations` class also provides auto-generated
   `localizationsDelegates` and `supportedLocales` lists.
   You can use these instead of providing them manually.

   `AppLocalizations` 类也可以自动自动生成
   `localizationsDelegates` 和 `supportedLocales` 列表，
   而无需手动提供它们。

   <?code-excerpt "gen_l10n_example/lib/examples.dart (material-app)"?>
   ```dart
   const MaterialApp(
     title: 'Localizations Sample App',
     localizationsDelegates: AppLocalizations.localizationsDelegates,
     supportedLocales: AppLocalizations.supportedLocales,
   );
   ```

8. Once the Material app has started,
   you can use `AppLocalizations` anywhere in your app:

   Material 应用启动后，
   你就可以在应用的任意地方使用 `AppLocalizations` 了:

   <?code-excerpt "gen_l10n_example/lib/main.dart (internationalized-title)"?>
   ```dart
   appBar: AppBar(
     // The [AppBar] title text should update its message
     // according to the system locale of the target platform.
     // Switching between English and Spanish locales should
     // cause this text to update.
     title: Text(AppLocalizations.of(context)!.helloWorld),
   ),
   ```

:::note

The Material app has to actually be started to initialize
`AppLocalizations`. If the app hasn't yet started,
`AppLocalizations.of(context)!.helloWorld` causes a
null exception.

Material 应用必须启动完成后才能初始化 `AppLocalizations`。
如果应用尚未完全启动，
`AppLocalizations.of(context)!.helloWorld` 将导致空异常。

:::

   This code generates a `Text` widget that displays "Hello World!"
   if the target device's locale is set to English,
   and "¡Hola Mundo!" if the target device's locale is set
   to Spanish. In the `arb` files,
   the key of each entry is used as the method name of the getter,
   while the value of that entry contains the localized message.
   
   如果目标设备的语言环境设置为英语，
   此代码生成的 `Text` widget 会展示「Hello World!」。
   如果目标设备的语言环境设置为西班牙语，则展示「Hola Mundo!」，
   在 `arb` 文件中，每个条目的键值都被用作 getter 的方法名称，
   而该条目的值则表示本地化的信息。

The [`gen_l10n_example`][] uses this tool.

要查看使用该工具的示例 Flutter 应用，请参阅 [`gen_l10n_example`][]。

To localize your device app description,
pass the localized string to
[`MaterialApp.onGenerateTitle`][]:

如需本地化设备应用描述，你可以将本地化后的字符串传递给
[`MaterialApp.onGenerateTitle`][]:

<?code-excerpt "intl_example/lib/main.dart (app-title)"?>
```dart
return MaterialApp(
  onGenerateTitle: (context) => DemoLocalizations.of(context).title,
```

[App Resource Bundle]: {{site.github}}/google/app-resource-bundle
[`gen_l10n_example`]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/gen_l10n_example
[`MaterialApp.onGenerateTitle`]: {{site.api}}/flutter/material/MaterialApp/onGenerateTitle.html

### Placeholders, plurals, and selects

### 占位符、复数和选项

:::tip

When using VS Code, add the [arb-editor extension][].
This extension adds syntax highlighting, snippets, 
diagnostics, and quick fixes to help edit `.arb` template files.

使用 VS Code 时，添加 [arb-editor 扩展][arb-editor extension] 。
该扩展可增添语法高亮显示、片段、诊断和快速修复功能，
以辅助编辑 `.arb` 模板文件。

:::

[arb-editor extension]: https://marketplace.visualstudio.com/items?itemName=Google.arb-editor

You can also include application values in a message with
special syntax that uses a _placeholder_ to generate a method
instead of a getter.
A placeholder, which must be a valid Dart identifier name,
becomes a positional parameter in the generated method in the
`AppLocalizations` code. Define a placeholder name by wrapping
it in curly braces as follows:

你还可以使用特殊语法在信息中包含应用程序的值，
该语法使用 _占位符_ 生成方法（并非 getter）。
占位符必须是有效的 Dart 标识符名称，
它将成为 `AppLocalizations` 代码中生成方法的位置参数。
用大括号定义占位符名称，如下所示：

```json
"{placeholderName}"
```

Define each placeholder in the `placeholders` object
in the app's `.arb` file. For example,
to define a hello message with a `userName` parameter,
add the following to `lib/l10n/app_en.arb`:

在应用程序 `.arb` 文件内的 `placeholders` 对象中定义每个占位符。
例如，需要定义带有 `userName` 参数的 hello 信息，
请在 `lib/l10n/app_en.arb` 中添加以下内容：

<?code-excerpt "gen_l10n_example/lib/l10n/app_en.arb" skip="5" take="10" replace="/},$/}/g"?>
```json
"hello": "Hello {userName}",
"@hello": {
  "description": "A message with a single parameter",
  "placeholders": {
    "userName": {
      "type": "String",
      "example": "Bob"
    }
  }
}
```

This code snippet adds a `hello` method call to
the `AppLocalizations.of(context)` object,
and the method accepts a parameter of type `String`;
the `hello` method returns a string.
Regenerate the `AppLocalizations` file.

此代码段为 `AppLocalizations.of(context)` 对象
添加了一个 `hello` 方法调用，
该方法接收一个 `String` 类型的参数；
`hello` 方法返回一个字符串。
重新生成 `AppLocalizations` 文件。

Replace the code passed into `Builder` with the following:

将 `Builder` 中的代码替换为以下代码：

<?code-excerpt "gen_l10n_example/lib/main.dart (placeholder)" remove="/wombat|Wombats|he'|they|pronoun/"?>
```dart
// Examples of internationalized strings.
return Column(
  children: <Widget>[
    // Returns 'Hello John'
    Text(AppLocalizations.of(context)!.hello('John')),
  ],
);
```

You can also use numerical placeholders to specify multiple values.
Different languages have different ways to pluralize words.
The syntax also supports specifying _how_ a word should be pluralized.
A _pluralized_ message must include a `num` parameter indicating
how to pluralize the word in different situations.
English, for example, pluralizes "person" to "people",
but that doesn't go far enough.
The `message0` plural might be "no people" or "zero people".
The `messageFew` plural might be
"several people", "some people", or "a few people". 
The `messageMany` plural might
be  "most people" or "many people", or "a crowd". 
Only the more general `messageOther` field is required.
The following example shows what options are available:

你还可以使用数字占位符来指定多个值。
不同的语言有不同的单词复数化形式。
该语法还支持指定单词的复数化形式。
一个 _复数化_ 信息必须包含一个 `num` 参数，
指明在不同情况下该单词的复数化形式。
例如，英语将「person」复数为「people」，但这还不够。
`message0` 的复数可能是「no people」或「zero people」。
`messageFew` 的复数可能是「several people」、「some people」或「a few people」。
`messageMany` 的复数可能是「most people」、「many people」或「a crowd」。
只有更通用的 `messageOther` 字段是必填的。
下面的示例显示了可用的选项：

```json
"{countPlaceholder, plural, =0{message0} =1{message1} =2{message2} few{messageFew} many{messageMany} other{messageOther}}"
```

The previous expression is replaced by the message variation
(`message0`, `message1`, ...) corresponding to the value
of the `countPlaceholder`.
Only the `messageOther` field is required.

前面的表达式由 `countPlaceholder` 值相对应的信息变量
（`message0`、`message1`、...）所替代。
只有 `messageOther` 字段是必填的。

The following example defines a message that pluralizes
the word, "wombat":

下面的示例定义了「袋熊」复数化的信息：

{% raw %}
<?code-excerpt "gen_l10n_example/lib/l10n/app_en.arb" skip="15" take="10" replace="/},$/}/g"?>
```json
"nWombats": "{count, plural, =0{no wombats} =1{1 wombat} other{{count} wombats}}",
"@nWombats": {
  "description": "A plural message",
  "placeholders": {
    "count": {
      "type": "num",
      "format": "compact"
    }
  }
}
```
{% endraw %}

Use a plural method by passing in the `count` parameter:

通过传递 `count` 参数来使用复数方法：

<?code-excerpt "gen_l10n_example/lib/main.dart (placeholder)" remove="/John|he|she|they|pronoun/" replace="/\[/[\n    .../g"?>
```dart
// Examples of internationalized strings.
return Column(
  children: <Widget>[
    ...
    // Returns 'no wombats'
    Text(AppLocalizations.of(context)!.nWombats(0)),
    // Returns '1 wombat'
    Text(AppLocalizations.of(context)!.nWombats(1)),
    // Returns '5 wombats'
    Text(AppLocalizations.of(context)!.nWombats(5)),
  ],
);
```

Similar to plurals,
you can also choose a value based on a `String` placeholder.
This is most often used to support gendered languages.
The syntax is as follows:

与复数类似，
你也可以根据 `String` 占位符选择一个值。
这通常用于性别。
语法如下：

```json
"{selectPlaceholder, select, case{message} ... other{messageOther}}"
```

The next example defines a message that
selects a pronoun based on gender:

下面的示例定义了一条信息，
该信息根据性别选择代词：

{% raw %}
<?code-excerpt "gen_l10n_example/lib/l10n/app_en.arb" skip="25" take="9" replace="/},$/}/g"?>
```json
"pronoun": "{gender, select, male{he} female{she} other{they}}",
"@pronoun": {
  "description": "A gendered message",
  "placeholders": {
    "gender": {
      "type": "String"
    }
  }
}
```
{% endraw %}

Use this feature by
passing the gender string as a parameter:

将性别字符串作为参数传递，
即可使用该功能：

<?code-excerpt "gen_l10n_example/lib/main.dart (placeholder)" remove="/'He|hello|ombat/" replace="/\[/[\n    .../g"?>
```dart
// Examples of internationalized strings.
return Column(
  children: <Widget>[
    ...
    // Returns 'he'
    Text(AppLocalizations.of(context)!.pronoun('male')),
    // Returns 'she'
    Text(AppLocalizations.of(context)!.pronoun('female')),
    // Returns 'they'
    Text(AppLocalizations.of(context)!.pronoun('other')),
  ],
);
```

Keep in mind that when using `select` statements,
comparison between the parameter and the actual
value is case-sensitive.
That is, `AppLocalizations.of(context)!.pronoun("Male")`
defaults to the "other" case, and returns "they".

请记住，在使用 `select` 语句时，
参数和实际值之间的比较是区分大小写的。
也就是说，`AppLocalizations.of(context)!.pronoun("Male")` 
默认为「other」，并返回「they」。

### Escaping syntax

### 避免语法解析

Sometimes, you have to use tokens,
such as `{` and `}`, as normal characters.
To ignore such tokens from being parsed,
enable the `use-escaping` flag by adding the
following to `l10n.yaml`:

有时你会使用符号（例如 `{` 或 `}`）作为普通文本的一部分。
如果你想要让它们不被解析为一种语法，可以在 `l10n.yaml` 中设置 `use-escaping`：

```yaml
use-escaping: true
```

The parser ignores any string of characters
wrapped with a pair of single quotes.
To use a normal single quote character,
use a pair of consecutive single quotes.
For example, the following text is converted
to a Dart `String`:

启用后，解析器会忽略使用一对单引号包括的文字，
如果在文字中又想使用单个单引号，需要使用成对的单引号进行转义。
例如，下面的文字会直接转为 Dart 的 `String`：

```json
{
  "helloWorld": "Hello! '{Isn''t}' this a wonderful day?"
}
```

The resulting string is as follows:

结果如下：

```dart
"Hello! {Isn't} this a wonderful day?"
```

### Messages with numbers and currencies

### 包含数字和货币的信息

Numbers, including those that represent currency values,
are displayed very differently in different locales. 
The localizations generation tool in
`flutter_localizations` uses the
[`NumberFormat`]({{site.api}}/flutter/intl/NumberFormat-class.html)
class in the `intl` package to format
numbers based on the locale and the desired format.

数字，包括那些代表货币价值的数字，
在不同的本地化环境中显示的方式大相径庭。
在 `flutter_localizations` 中的本地化生成工具
使用了 `intl` package 中的 
[`NumberFormat`]({{site.api}}/flutter/intl/NumberFormat-class.html) 
类，根据本地化和所需的格式来格式化数字。

The `int`, `double`, and `num` types can use any of the
following `NumberFormat` constructors:

`int`、`double` 和 `num` 类型可以使用
以下任何一个 `NumberFormat` 构造函数：

| <t>Message "format" value</t><t>信息「格式」值</t> | <t>Output for 1200000</t><t>输出为 1200000</t> |
| --------------------------- | ------------------ |
| `compact`                   | "1.2M"             |
| `compactCurrency`*          | "$1.2M"            |
| `compactSimpleCurrency`*    | "$1.2M"            |
| `compactLong`               | "1.2 million"      |
| `currency`*                 | "USD1,200,000.00"  |
| `decimalPattern`            | "1,200,000"        |
| `decimalPatternDigits`*     | "1,200,000"        |
| `decimalPercentPattern`*    | "120,000,000%"     |
| `percentPattern`            | "120,000,000%"     |
| `scientificPattern`         | "1E6"              |
| `simpleCurrency`*           | "$1,200,000"       |

{:.table .table-striped}

The starred `NumberFormat` constructors in the table
offer optional, named parameters.
Those parameters can be specified as the value
of the placeholder's `optionalParameters` object.
For example, to specify the optional `decimalDigits`
parameter for `compactCurrency`,
make the following changes to the `lib/l10n/app_en.arg` file:

表中带星<sup>(*)</sup>的 `NumberFormat` 构造函数提供了可选的命名参数。
这些参数可以指定为 placeholders 中 `optionalParameters` 对象的值。
例如，要为 `compactCurrency` 指定可选的 `decimalDigits` 参数，
请对 `lib/l10n/app_en.arg` 文件进行以下更改：

{% raw %}
<?code-excerpt "gen_l10n_example/lib/l10n/app_en.arb" skip="34" take="13" replace="/},$/}/g"?>
```json
"numberOfDataPoints": "Number of data points: {value}",
"@numberOfDataPoints": {
  "description": "A message with a formatted int parameter",
  "placeholders": {
    "value": {
      "type": "int",
      "format": "compactCurrency",
      "optionalParameters": {
        "decimalDigits": 2
      }
    }
  }
}
```
{% endraw %}

### Messages with dates

### 带日期的信息

Dates strings are formatted in many different ways
depending both the locale and the app's needs.  

日期字符串的格式有很多种，
取决于地区和应用程序的需求。

Placeholder values with type `DateTime` are formatted with
[`DateFormat`][] in the `intl` package.

`DateTime` 类型的占位符使用 `intl` package 中的 
[`DateFormat`][] 格式化。

There are 41 format variations,
identified by the names of their `DateFormat` factory constructors.
In the following example, the `DateTime` value
that appears in the `helloWorldOn` message is
formatted with `DateFormat.yMd`:

格式变体共有 41 种，
由 `DateFormat` factory 构造函数的名称标识。
在下面的示例种，
出现在 `helloWorldOn` 信息中的 `DateTime` 值
是用 `DateFormat.yMd` 进行的格式化：

```json
"helloWorldOn": "Hello World on {date}",
"@helloWorldOn": {
  "description": "A message with a date parameter",
  "placeholders": {
    "date": {
      "type": "DateTime",
      "format": "yMd"
    }
  }
}
```

In an app where the locale is US English,
the following expression would produce  "7/9/1959".
In a Russian locale, it would produce "9.07.1959".

在语言环境为英语（美国）的应用中，以下表达式将会是 7/9/1959，
在俄罗斯语言环境中，它将是 9.07.1959。

```dart
AppLocalizations.of(context).helloWorldOn(DateTime.utc(1959, 7, 9))
```

[`DateFormat`]: {{site.api}}/flutter/intl/DateFormat-class.html

<a id="ios-specifics"></a>
### Localizing for iOS: Updating the iOS app bundle

### iOS 本地化：更新 iOS app bundle

Although the localizations are handled by Flutter,
you need to add the supported languages in the Xcode project.
This ensures your entry in the App Store correctly displays
the supported languages.

虽然本地化由 Flutter 处理，
但你仍需要在 Xcode 项目中添加支持的语言。
这将确保你在 App Store 的条目中正确显示支持的语言。

To configure the locales supported by your app,
use the following instructions:

请按照以下说明，来配置应用支持的本地语言：

1. Open your project's `ios/Runner.xcodeproj` Xcode file.

   打开项目的 `ios/Runner.xcodeproj` Xcode 文件。

2. In the **Project Navigator**, select the `Runner` project
   file under **Projects**.

   在 **Project Navigator** 中，
   选择 **Projects** 下的 `Runner` 项目文件。

4. Select the `Info` tab in the project editor.

   在项目编辑器中选择 `Info` 选项卡。

5. In the **Localizations** section, click the `Add` button
   (`+`) to add the supported languages and regions to your
   project. When asked to choose files and reference language,
   simply select `Finish`.

   在 **Localizations** 部分，单击 `添加` 按钮 (`+`)，
   将支持的语言和地区添加到项目中。
   当要求选择文件和参考语言时，
   只需选择 `Finish` 即可。

7. Xcode automatically creates empty `.strings` files and
   updates the `ios/Runner.xcodeproj/project.pbxproj` file.
   These files are used by the App Store to determine which
   languages and regions your app supports.

   Xcode 会自动创建空的 `.strings` 文件并
   更新 `ios/Runner.xcodeproj/project.pbxproj` 文件。
   App Store 会使用这些文件来确定应用支持哪些语言和地区。

<a id="advanced-customization"></a>
## Advanced topics for further customization

## 定制的进阶操作

This section covers additional ways to customize a
localized Flutter application.

本节介绍自定义本地 Flutter 应用程序的其他方法。

<a id="advanced-locale"></a>
### Advanced locale definition

### 高级语言环境定义

Some languages with multiple variants require more than just a
language code to properly differentiate.

一些具有着多个变体的语言仅用 `languageCode` 来区分是不够充分的。

For example, fully differentiating all variants of
Chinese requires specifying the language code, script code,
and country code. This is due to the existence
of simplified and traditional script, as well as regional
differences in the way characters are written within the same script type.

例如，在多语言应用开发这个话题里，如果要更好的区分具有多种语言变体的中文，
则需要指定其 `languageCode`、`scriptCode` 和 `countryCode`。
因为目前有两种主要的，且存在地区使用差异的中文书写系统：简体和繁体。

In order to fully express every variant of Chinese for the
country codes `CN`, `TW`, and `HK`, the list of supported
locales should include:

为了让 `CN`、`TW` 和 `HK` 能够更充分地表示到每个中文变体，
构建应用时，设定支持的语言列表可以参考如下代码：

<?code-excerpt "gen_l10n_example/lib/examples.dart (supported-locales)"?>
```dart
supportedLocales: [
  Locale.fromSubtags(languageCode: 'zh'), // generic Chinese 'zh'
  Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
  ), // generic simplified Chinese 'zh_Hans'
  Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
  ), // generic traditional Chinese 'zh_Hant'
  Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hans',
    countryCode: 'CN',
  ), // 'zh_Hans_CN'
  Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'TW',
  ), // 'zh_Hant_TW'
  Locale.fromSubtags(
    languageCode: 'zh',
    scriptCode: 'Hant',
    countryCode: 'HK',
  ), // 'zh_Hant_HK'
],
```

This explicit full definition ensures that your app can
distinguish between and provide the fully nuanced localized
content to all combinations of these country codes.
If a user's preferred locale isn't specified,
Flutter selects the closest match,
which likely contains differences to what the user expects.
Flutter only resolves to locales defined in `supportedLocales`
and provides scriptCode-differentiated localized
content for commonly used languages.
See [`Localizations`][] for information on how the supported
locales and the preferred locales are resolved.

代码里这几组明确和完整的定义，
可以确保你的应用为各种不同首选语言环境的用户提供更加精细化的本地化内容。
如果用户没有指定首选的语言环境，那么我们就会使用最近的匹配，这可能与用户的期望会有差异。
Flutter 只会解析定义在 `supportedLocales` 里面的语言环境。
对于那些常用语言，Flutter 为本地化内容提供了文字代码级别的区分。
查看 [`Localizations`][] 了解 Flutter 是如何
解析支持的语言环境和首选的语言环境的。

Although Chinese is a primary example,
other languages like French (`fr_FR`, `fr_CA`)
should also be fully differentiated for more nuanced localization.

虽然中文是最主要的一个示例，
但是其他语言如法语（`fr_FR`，`fr_CA` 等等）
也应该为了更细致的本地化而做完全的区分。

[`Localizations`]: {{site.api}}/flutter/widgets/WidgetsApp/supportedLocales.html

<a id="tracking-locale"></a>
### Tracking the locale: The Locale class and the Localizations widget

### 获取语言环境：Locale 类和 Localizations Widget

The [`Locale`][] class identifies the user's language.
Mobile devices support setting the locale for all applications,
usually using a system settings menu.
Internationalized apps respond by displaying values that are
locale-specific. For example, if the user switches the device's locale
from English to French, then a `Text` widget that originally
displayed "Hello World" would be rebuilt with "Bonjour le monde".

[`Locale`][] 类用来识别用户的语言。
移动设备支持为所有的应用设置语言环境，经常是通过系统设置菜单来进行操作。
设置完之后，国际化的 app 就会展示成对应特定语言环境的值。
例如，如果用户把设备的语言环境从英语切换到法语，
显示 "Hello World" 的文本 widget 会使用 "Bonjour le monde" 进行重建。

The [`Localizations`][widgets-global] widget defines the locale
for its child and the localized resources that the child depends on.
The [`WidgetsApp`][] widget creates a `Localizations` widget
and rebuilds it if the system's locale changes.

[`Localizations`][widgets-global]
widget 定义了它的子节点的语言环境和依赖的本地化的资源。
[`WidgetsApp`][] 创建了一个本地化的 widget，
如果系统的语言环境变化了，它会重建这个 widget。

You can always look up an app's current locale with
`Localizations.localeOf()`:

你可以通过调用 `Localizations.localeOf()`
方法来查看 app 当前的语言环境:

<?code-excerpt "gen_l10n_example/lib/examples.dart (my-locale)"?>
```dart
Locale myLocale = Localizations.localeOf(context);
```

[`Locale`]: {{site.api}}/flutter/dart-ui/Locale-class.html
[`WidgetsApp`]: {{site.api}}/flutter/widgets/WidgetsApp-class.html
[widgets-global]: {{site.api}}/flutter/flutter_localizations/GlobalWidgetsLocalizations-class.html

<a id="specifying-supportedlocales"></a>
### Specifying the app's supported&shy;Locales parameter

### 指定应用程序 supported­Locales 参数

Although the `flutter_localizations` library currently supports
{{languageCount}} languages and language variants, only English language translations
are available by default. It's up to the developer to decide exactly
which languages to support.

尽管 `flutter_localizations` 库目前支持 {{languageCount}} 种语言和语言变体，
但默认情况下仅提供英语译文。
具体支持哪些语言由开发人员决定。

The `MaterialApp` [`supportedLocales`][]
parameter limits locale changes. When the user changes the locale
setting on their device, the app's `Localizations` widget only
follows suit if the new locale is a member of this list.
If an exact match for the device locale isn't found,
then the first supported locale with a matching [`languageCode`][]
is used. If that fails, then the first element of the
`supportedLocales` list is used.

`MaterialApp` 的 [`supportedLocales`][] 参数限制了本地化设置的更改。
当用户更改设备上的语言设置时，
只有在 [`supportedLocales`][] 参数列表中包含了用户更改的本地化语言设置的情况下，
应用程序的 `Localizations` widget 才会生效。
如果找不到与设备本地化完全匹配的语言，
则会使用与 [`languageCode`][] 匹配的第一个受支持的语言。
如果仍然找不到，
则使用 `supportedLocales` 列表中的第一个元素。

An app that wants to use a different "locale resolution"
method can provide a [`localeResolutionCallback`][].
For example, to have your app unconditionally accept
whatever locale the user selects:

如果应用程序希望使用不同的「本地化解析」方法，
可以提供 [`localeResolutionCallback`][]。
例如，应用程序可以无条件接受用户选择的任何语言：

<?code-excerpt "gen_l10n_example/lib/examples.dart (locale-resolution)"?>
```dart
MaterialApp(
  localeResolutionCallback: (locale, supportedLocales) {
    return locale;
  },
);
```

[`languageCode`]: {{site.api}}/flutter/dart-ui/Locale/languageCode.html
[`localeResolutionCallback`]: {{site.api}}/flutter/widgets/LocaleResolutionCallback.html
[`supportedLocales`]: {{site.api}}/flutter/material/MaterialApp/supportedLocales.html

### Configuring the l10n.yaml file

### 配置 l10n.yaml 文件

The `l10n.yaml` file allows you to configure the `gen-l10n` tool
to specify the following:

通过 `l10n.yaml` 文件，
你可以配置 `gen-l10n` 工具，
指定以下内容：

* where all the input files are located

  所有输入文件的位置

* where all the output files should be created

  所有输出文件的创建位置

* what Dart class name to give your localizations delegate

  为本地化委托赋予自定义的 Dart 类名

For a full list of options, either run `flutter gen-l10n --help`
at the command line or refer to the following table:

获取完整的选项列表，
可在命令行中运行 `flutter gen-l10n --help` 
或参考下表内容：

| <t>Option</t><t>可选项</t>           | <t>Description</t><t>说明</t> |
| ------------------------------------| ------------------ |
| `arb-dir`                           | The directory where the template and translated arb files are located. The default is `lib/l10n`. |
| `arb-dir`                           | 模板和翻译 arb 文件所在的目录。 默认为 `lib/l10n`。 |
| `output-dir`                        | The directory where the generated localization classes are written. This option is only relevant if you want to generate the localizations code somewhere else in the Flutter project. You also need to set the `synthetic-package` flag to false.<br /><br />The app must import the file specified in the `output-localization-file` option from this directory. If unspecified, this defaults to the same directory as the input directory specified in `arb-dir`. |
| `output-dir`                        | 生成本地化类的目录。 只有当你想在 Flutter 项目的其他位置生成本地化代码时，才需要使用此选项。 你还需要将 `synthetic-package` 标志设为 false。<br /><br /> 应用程序必须从该目录导入 `output-localization-file` 选项中指定的文件。 如果未指定，则默认与 `arb-dir` 中指定的输入目录相同。 |
| `template-arb-file`                 | The template arb file that is used as the basis for generating the Dart localization and messages files. The default is `app_en.arb`. |
| `template-arb-file`                 | 用于生成 Dart 本地化和信息文件的 arb 模板文件。 默认为 `app_en.arb`。 |
| `output-localization-file`          | The filename for the output localization and localizations delegate classes. The default is `app_localizations.dart`. |
| `output-localization-file`          | 输出本地化和本地化委托类的文件名。 默认为 `app_localizations.dart`。 |
| `untranslated-messages-file`        | The location of a file that describes the localization messages haven't been translated yet. Using this option creates a JSON file at the target location, in the following format: <br /> <br />`"locale": ["message_1", "message_2" ... "message_n"]`<br /><br /> If this option is not specified, a summary of the messages that haven't been translated are printed on the command line. |
| `untranslated-messages-file`        | 描述尚未翻译的本地化信息的文件位置。 使用该选项会在目标位置创建一个 JSON 文件，格式如下：<br /><br /> `"locale": ["message_1", "message_2" ... "message_n"]` <br /><br /> 如果未指定此选项，则会在命令行中打印尚未翻译的信息摘要。 |
| `output-class`                      | The Dart class name to use for the output localization and localizations delegate classes. The default is `AppLocalizations`. |
| `output-class`                      | 用于输出本地化和本地化委托类的 Dart 类名。 默认为 `AppLocalizations`。 |
| `preferred-supported-locales`       | The list of preferred supported locales for the application. By default, the tool generates the supported locales list in alphabetical order. Use this flag to default to a different locale.<br /><br />For example, pass in `[ en_US ]` to default to American English if a device supports it. |
| `preferred-supported-locales`       | 应用程序首选支持的本地语言列表。 默认情况下，工具会按字母顺序生成支持的本地语言列表。 使用此标记可默认为不同的本地语言。 <br /><br /> 例如，设备支持美式英语，则输入 `[ en_US ]` 默认为美式英语。 |
| `header`                            | The header to prepend to the generated Dart localizations files. This option takes in a string.<br /><br />For example, pass in `"/// All localized files."` to prepend this string to the generated Dart file.<br /><br />Alternatively, check out the `header-file` option to pass in a text file for longer headers. |
| `header`                            | 在生成的 Dart 本地化文件中预置头文件。 该选项包含一个字符串。 <br /><br /> 例如，输入 `"/// All localized files."`，就会在生成的 Dart 文件中预置这个字符串。 <br /><br /> 或者，还可以使用 `header-file` 选项来传递一个文本文件，以获得更长的头文件。 |
| `header-file`                       | The header to prepend to the generated Dart localizations files. The value of this option is the name of the file that contains the header text that is inserted at the top of each generated Dart file. <br /><br /> Alternatively, check out the `header` option to pass in a string for a simpler header.<br /><br />This file should be placed in the directory specified in `arb-dir`. |
| `header-file`                       | 在生成的 Dart 本地化文件中预置头文件。 该选项的值是包含头文件文本的文件名，头文件文本将插入每个生成的 Dart 文件的顶部。 <br /><br /> 或者，还可以使用 `header` 选项来传递一个字符串，以获得更简单的头文件。 <br /><br /> 该文件应放在 `arb-dir` 中指定的目录下。 |
| `[no-]use-deferred-loading`         | Specifies whether to generate the Dart localization file with locales imported as deferred, allowing for lazy loading of each locale in Flutter web.<br /><br />This can reduce a web app's initial startup time by decreasing the size of the JavaScript bundle. When this flag is set to true, the messages for a particular locale are only downloaded and loaded by the Flutter app as they are needed. For projects with a lot of different locales and many localization strings, it can improve performance to defer loading. For projects with a small number of locales, the difference is negligible, and might slow down the start up compared to bundling the localizations with the rest of the application.<br /><br />Note that this flag doesn't affect other platforms such as mobile or desktop. |
| `[no-]use-deferred-loading`         | 指定是否将生成的 Dart 本地化文件延迟导入，以便在 Flutter web 中对每个本地化进行懒加载。 <br /><br /> 这可以减少 JavaScript 程序的大小，从而缩短 web 应用的初始启动时间。 当此标记设置为 true 时，Flutter 应用程序只会在需要时下载和加载特定语言的信息。 对于具有大量不同本地化字符串的项目，延迟加载可以提高性能。 对于本地化字符串数量较少的项目，两者之间的差异可以忽略不计，但是将本地化字符串与应用程序的其他部分捆绑在一起相比，可能会降低启动速度。 <br /><br /> 请注意，此标记不会影响移动或桌面等其他平台。 |
| `gen-inputs-and-outputs-list`      | When specified, the tool generates a JSON file containing the tool's inputs and outputs, named `gen_l10n_inputs_and_outputs.json`.<br /><br />This can be useful for keeping track of which files of the Flutter project were used when generating the latest set of localizations.  For example, the Flutter tool's build system uses this file to keep track of when to call gen_l10n during hot reload.<br /><br />The value of this option is the directory where the JSON file is generated.  When null, the JSON file won't be generated. |
| `gen-inputs-and-outputs-list`      | 指定后，工具会生成一个 JSON 文件，其中包含工具的输入和输出的内容，文件名为 `gen_l10n_inputs_and_outputs.json`。 <br /><br /> 这对于追踪生成最新的本地化时使用了 Flutter 项目中的哪些文件非常有用。 例如，Flutter 工具的构建系统会使用此文件来追踪在热重载期间何时调用 gen_l10n。 <br /><br /> 该选项的值是生成 JSON 文件的目录。 如果为空，则不会生成 JSON 文件。 |
| `synthetic-package`                 | Determines  whether the generated output files are generated as a synthetic package or at a specified directory in the Flutter project. This flag is `true` by default. When `synthetic-package` is set to `false`, it generates the localizations files in the directory specified by `arb-dir` by default. If `output-dir` is specified, files are generated there. |
| `synthetic-package`                 | 决定生成的输出文件是作为 synthetic package 还是在 Flutter 项目中指定的目录下生成。 该标志默认为 `true`。  `synthetic-package` 设置为 `false` 时，默认会在 `arb-dir` 指定的目录下生成本地化文件。 如果指定了 `output-dir` 目录，则会在该目录下生成文件。 |
| `project-dir`                       | When specified, the tool uses the path passed into this option as the directory of the root Flutter project.<br /><br />When null, the relative path to the present working directory is used. |
| `project-dir`                       | 指定后，工具将使用此选项中传递的路径作为 Flutter 项目的根目录。 <br /><br /> 如果为空，则使用当前工作目录的相对路径。 |
| `[no-]required-resource-attributes` | Requires all resource ids to contain a corresponding resource attribute.<br /><br />By default, simple messages won't require metadata, but it's highly recommended as this provides context for the meaning of a message to readers.<br /><br />Resource attributes are still required for plural messages. |
| `[no-]required-resource-attributes` | 要求所有资源 ID 包含相应的资源属性。 <br /><br /> 默认情况下，简单信息不需要元数据，但强烈建议使用元素据，因为它能为读者提供信息含义的上下文。 <br /><br /> 复数信息仍然需要资源属性。 |
| `[no-]nullable-getter`              | Specifies whether the localizations class getter is nullable.<br /><br />By default, this value is true so that `Localizations.of(context)` returns a nullable value for backwards compatibility. If this value is false, then a null check is performed on the returned value of `Localizations.of(context)`, removing the need for null checking in user code. |
| `[no-]nullable-getter`              | 指定本地化类 getter 是否可为空。 <br /><br /> 默认情况下，该值为 true，这样 `Localizations.of(context)` 就会返回一个可归零的值，以实现向下兼容。 如果该值为 false，则会对 `Localizations.of(context)` 返回的值进行空值检查，从而无需在用户代码中进行空值检查。 |
| `[no-]format`                       | When specified, the `dart format` command is run after generating the localization files. |
| `[no-]format`                       | 指定后，将在生成本地化文件后运行 `dart format` 指令。 |
| `use-escaping`                      | Specifies whether to enable the use of single quotes as escaping syntax. |
| `use-escaping`                      | 指定是否启用单引号作为转义语法。 |
| `[no-]suppress-warnings`            | When specified, all warnings are suppressed. |
| `[no-]suppress-warnings`            | 指定后，将不会进行警告。 |
| `[no-]relax-syntax`                 | When specified, the syntax is relaxed so that the special character "{" is treated as a string if not followed by a valid placeholder and "}" is treated as a string if it doesn't close any previous "{" that is treated as a special character. |
| `[no-]relax-syntax`                 | 指定后，语法会变得宽松：如果特殊字符“{”后面没有有效的占位符，它将被视为字符串；如果“}”无法配对之前的特殊字符“{”，它也将被视为字符串。 |
| `[no-]use-named-parameters`         | Whether to use named parameters for the generated localization methods. |
| `[no-]use-named-parameters`         | 是否为生成的本地化方法使用命名参数。 |

{:.table .table-striped}


## How internationalization in Flutter works

## Flutter 里的国际化是如何工作的

This section covers the technical details of how localizations work
in Flutter. If you're planning on supporting your own set of localized
messages, the following content would be helpful.
Otherwise, you can skip this section.

本节涵盖了 Flutter 中本地化工作的技术细节，
如果你计划使用自定的一套本地化信息，下面的内容会很有帮助。
反之则可以跳过本节。

<a id="loading-and-retrieving"></a>
### Loading and retrieving localized values

### 加载和获取本地化值

The `Localizations` widget is used to load and
look up objects that contain collections of localized values.
Apps refer to these objects with [`Localizations.of(context,type)`][].
If the device's locale changes,
the `Localizations` widget automatically loads values for
the new locale and then rebuilds widgets that used it.
This happens because `Localizations` works like an
[`InheritedWidget`][].
When a build function refers to an inherited widget,
an implicit dependency on the inherited widget is created.
When an inherited widget changes
(when the `Localizations` widget's locale changes),
its dependent contexts are rebuilt.

我们使用 `Localizations` widget 来加载和查询那些包含本地化值集合的对象。
app 通过调用 [`Localizations.of(context,type)`][] 来引用这些对象。
如果设备的语言环境变化了，Localizations widget 会自动地加载新的语言环境的值，
然后重建那些使用了语言环境的 widget。
这是因为 `Localizations` 像 [继承 widget][`InheritedWidget`] 一样执行。
当一个构建过程涉及到继承 widget，对继承 widget 的隐式依赖就创建了。
当一个继承 widget 变化了（即 Localizations widget 的语言环境变化），
它的依赖上下文就会被重建。

Localized values are loaded by the `Localizations` widget's
list of [`LocalizationsDelegate`][]s.
Each delegate must define an asynchronous [`load()`][]
method that produces an object that encapsulates a
collection of localized values.
Typically these objects define one method per localized value.

本地化的值是通过使用 `Localizations` widget 的 [`LocalizationsDelegate`] 加载的。
每一个 delegate 必须定义一个异步的 [`load()`][] 方法。
这个方法生成了一个封装本地化值的对象，
通常这些对象为每个本地化的值定义了一个方法。

In a large app, different modules or packages might be bundled with
their own localizations. That's why the `Localizations` widget
manages a table of objects, one per `LocalizationsDelegate`.
To retrieve the object produced by one of the `LocalizationsDelegate`'s
`load` methods, specify a `BuildContext` and the object's type.

在一个大型的 app 中，
不同的模块或者 package 需要和它们对应的本地化资源打包在一起。
这就是为什么 `Localizations` widget 管理着对象的一个对应表，
每个 `LocalizationsDelegate` 对应一个对象。
为了获得由 `LocalizationsDelegate` 的 `load` 方法生成的对象，
你需要指定一个构建上下文 (`BuildContext`) 和对象的类型。

For example,
the localized strings for the Material Components widgets
are defined by the [`MaterialLocalizations`][] class.
Instances of this class are created by a `LocalizationDelegate`
provided by the [`MaterialApp`][] class.
They can be retrieved with `Localizations.of()`:

例如，Material 组件 widget 的本地化字符串是由 [`MaterialLocalizations`][]
类定义的。这个类的实例是由 [[`MaterialApp`][] 
类提供的一个 `LocalizationDelegate` 方法创建的，
它们可以通过 `Localizations.of` 方法获得。

```dart
Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
```

This particular `Localizations.of()` expression is used frequently,
so the `MaterialLocalizations` class provides a convenient shorthand:

因为这个特定的 `Localizations.of()` 表达式经常使用，
所以 `MaterialLocalizations` 类提供了一个快捷访问：

```dart
static MaterialLocalizations of(BuildContext context) {
  return Localizations.of<MaterialLocalizations>(context, MaterialLocalizations);
}

/// References to the localized values defined by MaterialLocalizations
/// are typically written like this:

tooltip: MaterialLocalizations.of(context).backButtonTooltip,
```

[`InheritedWidget`]: {{site.api}}/flutter/widgets/InheritedWidget-class.html
[`load()`]: {{site.api}}/flutter/widgets/LocalizationsDelegate/load.html
[`LocalizationsDelegate`]: {{site.api}}/flutter/widgets/LocalizationsDelegate-class.html
[`Localizations.of(context,type)`]: {{site.api}}/flutter/widgets/Localizations/of.html
[`MaterialApp`]: {{site.api}}/flutter/material/MaterialApp-class.html
[`MaterialLocalizations`]: {{site.api}}/flutter/material/MaterialLocalizations-class.html

<a id="defining-class"></a>
### Defining a class for the app's localized resources

### 为 app 的本地化资源定义一个类

Putting together an internationalized Flutter app usually
starts with the class that encapsulates the app's localized values.
The example that follows is typical of such classes.

综合所有这些在一起，一个需要国际化的 app 经常以一个封装 app 本地化值的类开始的。
下面是使用这种类的典型示例。

Complete source code for the [`intl_example`][] for this app.

此示例 app 的 [完整的源码][`intl_example`]。

This example is based on the APIs and tools provided by the
[`intl`][] package. The [An alternative class for the app's
localized resources](#alternative-class) section
describes [an example][] that doesn't depend on the `intl` package.

这个示例是基于 [`intl`][] package 提供的 API 和 工具开发的，
[app 本地化资源的替代方法](#alternative-class)
里面讲解了一个不依赖于 intl package 的 [示例][an example]。

The `DemoLocalizations` class defined below
contains the app's strings (just one for the example)
translated into the locales that the app supports.
It uses the `initializeMessages()` function
generated by Dart's [`intl`][] package,
[`Intl.message()`][], to look them up.

`DemoLocalizations` 类包含了 app 语言环境内支持的
已经翻译成了本地化语言的字符串（本例子只有一个）。
它通过调用由 Dart 的 [`intl`][] package 生成的
`initializeMessages()` 方法来加载翻译好的字符串，
然后使用 [`Intl.message()`][] 来查阅它们。

<?code-excerpt "intl_example/lib/main.dart (demo-localizations)"?>
```dart
class DemoLocalizations {
  DemoLocalizations(this.localeName);

  static Future<DemoLocalizations> load(Locale locale) {
    final String name =
        locale.countryCode == null || locale.countryCode!.isEmpty
        ? locale.languageCode
        : locale.toString();
    final String localeName = Intl.canonicalizedLocale(name);

    return initializeMessages(localeName).then((_) {
      return DemoLocalizations(localeName);
    });
  }

  static DemoLocalizations of(BuildContext context) {
    return Localizations.of<DemoLocalizations>(context, DemoLocalizations)!;
  }

  final String localeName;

  String get title {
    return Intl.message(
      'Hello World',
      name: 'title',
      desc: 'Title for the Demo application',
      locale: localeName,
    );
  }
}
```

A class based on the `intl` package imports a generated
message catalog that provides the `initializeMessages()`
function and the per-locale backing store for `Intl.message()`.
The message catalog is produced by an [`intl` tool](#dart-tools)
that analyzes the source code for classes that contain
`Intl.message()` calls.
In this case that would just be the `DemoLocalizations` class.

基于 `intl` package 的类引入了一个生成好的信息目录，
它提供了 `initializeMessage()` 方法和 `Intl.message()` 方法的
每个语言环境的备份存储。
[`intl` 工具](#dart-tools) 通过分析包含 `Intl.message()`
调用类的源码生成这个信息目录。在当前情况下，
就是 DemoLocalizations 的类（包含了 `Intl.message()` 调用）。

[an example]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/minimal
[`intl`]: {{site.pub-pkg}}/intl
[`Intl.message()`]: {{site.pub-api}}/intl/latest/intl/Intl/message.html

<a id="adding-language"></a>
### Adding support for a new language

### 添加支持新的语言

An app that needs to support a language that's not included in
[`GlobalMaterialLocalizations`][] has to do some extra work:
it must provide about 70 translations ("localizations")
for words or phrases and the date patterns and symbols for the
locale.

如果你要开发一个 app 需要支持的语言不在 [`GlobalMaterialLocalizations`][] 当中，
那就需要做一些额外的工作：它必须提供大概 70 个字和词还有日期以及符号的翻译（本地化）。

See the following for an example of how to add
support for the Norwegian Nynorsk language.

举个例子，我们将给大家展示如何支持挪威尼诺斯克语。

A new `GlobalMaterialLocalizations` subclass defines the
localizations that the Material library depends on.
A new `LocalizationsDelegate` subclass, which serves
as factory for the `GlobalMaterialLocalizations` subclass,
must also be defined.

我们需要定义一个新的 `GlobalMaterialLocalizations` 子类，
它定义了 Material 库依赖的本地化资源。
同时，我们也必须定义一个新的 `LocalizationsDelegate` 子类，
它是给 `GlobalMaterialLocalizations` 子类作为一个工厂使用的。

Here's the source code for the complete [`add_language`][] example,
minus the actual Nynorsk translations.

这是支持添加一种新语言的[一个完整例子的源码][`add_language`]，
相对实际上要翻译的尼诺斯克语数量，我们只翻译了一小部分。

The locale-specific `GlobalMaterialLocalizations` subclass
is called `NnMaterialLocalizations`,
and the `LocalizationsDelegate` subclass is
`_NnMaterialLocalizationsDelegate`.
The value of `NnMaterialLocalizations.delegate`
is an instance of the delegate, and is all
that's needed by an app that uses these localizations.

这个特定语言环境的 `GlobalMaterialLocalizations`
子类被称为 `NnMaterialLocalizations`，
`LocalizationsDelegate` 子类被称为 `_NnMaterialLocalizationsDelegate`。
`BeMaterialLocalizations.delegate` 是 delegate 的一个实例，
这就是 app 使用这些本地化所需要的全部。

The delegate class includes basic date and number format
localizations. All of the other localizations are defined by `String`
valued property getters in `NnMaterialLocalizations`, like this:

delegate 类包括基本的日期和数字格式的本地化。
其他所有的本地化是由 `BeMaterialLocalizations`
里面的 `String` 字符串值属性的 getters 所定义的，
像下面这样：

<?code-excerpt "add_language/lib/nn_intl.dart (getters)"?>
```dart
@override
String get moreButtonTooltip => r'More';

@override
String get aboutListTileTitleRaw => r'About $applicationName';

@override
String get alertDialogLabel => r'Alert';
```

These are the English translations, of course.
To complete the job you need to change the return
value of each getter to an appropriate Nynorsk string.

当然，这些都是英语翻译。为了完成本地化操作，
你需要把每一个 getter 的返回值翻译成合适的
新挪威语 (Nynorsk) 字符串。

The getters return "raw" Dart strings that have an `r` prefix,
such as `r'About $applicationName'`,
because sometimes the strings contain variables with a `$` prefix.
The variables are expanded by parameterized localization methods:

像 `r'About $applicationName'` 一样，
这些带 r 前缀的 getters 返回的是原始的字符串，
因为有一些时候这些字符串会包含一些带有 `$` 前缀的变量。
通过调用带参数的本地化方法，这些变量会被替换：

<?code-excerpt "add_language/lib/nn_intl.dart (raw)"?>
```dart
@override
String get pageRowsInfoTitleRaw => r'$firstRow–$lastRow of $rowCount';

@override
String get pageRowsInfoTitleApproximateRaw =>
    r'$firstRow–$lastRow of about $rowCount';
```

The date patterns and symbols of the locale also need to
be specified, which are defined in the source code as follows:

语言对应的日期格式和符号需要一并指定。
在源码中，它们会以下列形式进行定义：

{% comment %}
RegEx adds last two lines with commented out code and closing bracket.
{% endcomment %}

<?code-excerpt "add_language/lib/nn_intl.dart (date-patterns)" replace="/  'LLL': 'LLL',/  'LLL': 'LLL',\n  \/\/ ...\n}/g"?>
```dart
const nnLocaleDatePatterns = {
  'd': 'd.',
  'E': 'ccc',
  'EEEE': 'cccc',
  'LLL': 'LLL',
  // ...
}
```

{% comment %}
RegEx adds last two lines with commented out code and closing bracket.
{% endcomment %}

<?code-excerpt "add_language/lib/nn_intl.dart (date-symbols)" replace="/  ],/  ],\n  \/\/ ...\n}/g"?>
```dart
const nnDateSymbols = {
  'NAME': 'nn',
  'ERAS': <dynamic>['f.Kr.', 'e.Kr.'],
```

These values need to be modified for the locale to use the correct
date formatting. Unfortunately, since the `intl` library doesn't
share the same flexibility for number formatting,
the formatting for an existing locale must be used
as a substitute in `_NnMaterialLocalizationsDelegate`:

上列内容需要修改以匹配语言的正确日期格式。
可惜的是，`intl` 并不具备数字格式的灵活性，
以至于 `_NnMaterialLocalizationsDelegate` 需要使用
现有的语言的格式作为替代方法：

<?code-excerpt "add_language/lib/nn_intl.dart (delegate)"?>
```dart
class _NnMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _NnMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'nn';

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    final String localeName = intl.Intl.canonicalizedLocale(locale.toString());

    // The locale (in this case `nn`) needs to be initialized into the custom
    // date symbols and patterns setup that Flutter uses.
    date_symbol_data_custom.initializeDateFormattingCustom(
      locale: localeName,
      patterns: nnLocaleDatePatterns,
      symbols: intl.DateSymbols.deserializeFromMap(nnDateSymbols),
    );

    return SynchronousFuture<MaterialLocalizations>(
      NnMaterialLocalizations(
        localeName: localeName,
        // The `intl` library's NumberFormat class is generated from CLDR data
        // (see https://github.com/dart-lang/i18n/blob/main/pkgs/intl/lib/number_symbols_data.dart).
        // Unfortunately, there is no way to use a locale that isn't defined in
        // this map and the only way to work around this is to use a listed
        // locale's NumberFormat symbols. So, here we use the number formats
        // for 'en_US' instead.
        decimalFormat: intl.NumberFormat('#,##0.###', 'en_US'),
        twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'en_US'),
        // DateFormat here will use the symbols and patterns provided in the
        // `date_symbol_data_custom.initializeDateFormattingCustom` call above.
        // However, an alternative is to simply use a supported locale's
        // DateFormat symbols, similar to NumberFormat above.
        fullYearFormat: intl.DateFormat('y', localeName),
        compactDateFormat: intl.DateFormat('yMd', localeName),
        shortDateFormat: intl.DateFormat('yMMMd', localeName),
        mediumDateFormat: intl.DateFormat('EEE, MMM d', localeName),
        longDateFormat: intl.DateFormat('EEEE, MMMM d, y', localeName),
        yearMonthFormat: intl.DateFormat('MMMM y', localeName),
        shortMonthDayFormat: intl.DateFormat('MMM d'),
      ),
    );
  }

  @override
  bool shouldReload(_NnMaterialLocalizationsDelegate old) => false;
}
```

For more information about localization strings,
check out the [flutter_localizations README][].

需要了解更多关于本地化字符串的内容，可以查看 [flutter_localizations README][]。

Once you've implemented your language-specific subclasses of
`GlobalMaterialLocalizations` and `LocalizationsDelegate`,
you  need to add the language and a delegate instance to your app.
The following code sets the app's language to Nynorsk and
adds the `NnMaterialLocalizations` delegate instance to the app's
`localizationsDelegates` list:

一旦你实现了指定语言的
`GlobalMaterialLocalizations` 和 `LocalizationsDelegate` 的子类，
你只需要给你的 app 添加此语言以及一个 delegate 的实例。
这里有一些代码展示了如何设置 app 的语言为尼诺斯克语以及如何给 app 的
`localizationsDelegates` 列表添加 `NnMaterialLocalizations` delegate 实例。

<?code-excerpt "add_language/lib/main.dart (material-app)"?>
```dart
const MaterialApp(
  localizationsDelegates: [
    GlobalWidgetsLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    NnMaterialLocalizations.delegate, // Add the newly created delegate
  ],
  supportedLocales: [Locale('en', 'US'), Locale('nn')],
  home: Home(),
),
```

[`add_language`]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/add_language/lib/main.dart

[flutter_localizations README]: {{site.repo.flutter}}/blob/main/packages/flutter_localizations/lib/src/l10n/README.md
[`GlobalMaterialLocalizations`]: {{site.api}}/flutter/flutter_localizations/GlobalMaterialLocalizations-class.html

<a id="alternative-internationalization-workflows"></a>
## Alternative internationalization workflows
  
## 其他的国际化方法

This section describes different approaches to internationalize
your Flutter application.

本节主要介绍国际化 Flutter 应用的不同方法。

<a id="alternative-class"></a>
### An alternative class for the app's localized resources

### 应用程序本地化资源的替代类

The previous example was defined in terms of the Dart `intl`
package. You can choose your own approach for managing
localized values for the sake of simplicity or perhaps to integrate
with a different i18n framework.

之前的示例应用主要根据 Dart `intl` package 定义，为了简单起见，
或者可能想要与不同的 i18n 框架集成，开发者也可以选择自己的方法来管理本地化的值。

Complete source code for the [`minimal`][] app.

点击查看 [`minimal`][] 应用的完整源代码。

In the following example, the `DemoLocalizations` class 
includes all of its translations directly in per language Maps:

在下面这个样例中，包含应用本地化版本的类 `DemoLocalizations`
直接在每种语言的 Map 中包括了所有的翻译。

<?code-excerpt "minimal/lib/main.dart (demo)"?>
```dart
class DemoLocalizations {
  DemoLocalizations(this.locale);

  final Locale locale;

  static DemoLocalizations of(BuildContext context) {
    return Localizations.of<DemoLocalizations>(context, DemoLocalizations)!;
  }

  static const _localizedValues = <String, Map<String, String>>{
    'en': {'title': 'Hello World'},
    'es': {'title': 'Hola Mundo'},
  };

  static List<String> languages() => _localizedValues.keys.toList();

  String get title {
    return _localizedValues[locale.languageCode]!['title']!;
  }
}
```

In the minimal app the `DemoLocalizationsDelegate` is slightly
different. Its `load` method returns a [`SynchronousFuture`][]
because no asynchronous loading needs to take place.

在 minimal 应用中，`DemoLocalizationsDelegate` 略有不同，
它的 `load` 方法返回一个 [`SynchronousFuture`][]，因为不需要进行异步加载。

<?code-excerpt "minimal/lib/main.dart (delegate)"?>
```dart
class DemoLocalizationsDelegate
    extends LocalizationsDelegate<DemoLocalizations> {
  const DemoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      DemoLocalizations.languages().contains(locale.languageCode);

  @override
  Future<DemoLocalizations> load(Locale locale) {
    // Returning a SynchronousFuture here because an async "load" operation
    // isn't needed to produce an instance of DemoLocalizations.
    return SynchronousFuture<DemoLocalizations>(DemoLocalizations(locale));
  }

  @override
  bool shouldReload(DemoLocalizationsDelegate old) => false;
}
```

[`SynchronousFuture`]: {{site.api}}/flutter/foundation/SynchronousFuture-class.html

<a id="dart-tools"></a>
### Using the Dart intl tools

### 附录：使用 Dart intl 工具

Before building an API using the Dart [`intl`][] package,
review the `intl` package's documentation.
The following list summarizes the process for
localizing an app that depends on the `intl` package:

在你使用 Dart [`intl`][] package 进行构建 API 之前，
你应该想要了解一下 `intl` package 的文档。

The demo app depends on a generated source file called
`l10n/messages_all.dart`, which defines all of the
localizable strings used by the app.

这个 demo app 依赖于一个生成的源文件，叫做 `l10n/messages_all.dart`，
这个文件定义了 app 使用的所有本地化的字符串。

Rebuilding `l10n/messages_all.dart` requires two steps.

重建 `l10n/messages_all.dart` 需要 2 步。

 1. With the app's root directory as the current directory,
    generate `l10n/intl_messages.arb` from `lib/main.dart`:

    在 app 的根目录，使用 `lib/main.dart` 生成 `l10n/intl_messages.arb`：

    ```console
    $ dart run intl_translation:extract_to_arb --output-dir=lib/l10n lib/main.dart
    ```

    The `intl_messages.arb` file is a JSON format map with one entry for
    each `Intl.message()` function defined in `main.dart`.
    This file serves as a template for the English and Spanish translations,
    `intl_en.arb` and `intl_es.arb`.
    These translations are created by you, the developer.

    `intl_messages.arb` 是一个 JSON 格式的文件，
    每一个入口代表定义在 `main.dart` 里面的 `Intl.message()` 方法。
    `intl_en.arb` 和 `intl_es.arb` 分别作为英语和西班牙语翻译的模板。
    这些翻译是由你（开发者）来创建的。

 2. With the app's root directory as the current directory,
    generate `intl_messages_<locale>.dart` for each
    `intl_<locale>.arb` file and `intl_messages_all.dart`,
    which imports all of the messages files:

    在 app 的根目录，生成每个 `intl_<locale>.arb` 
    文件对应的 `intl_messages_<locale>.dart` 文件，
    以及 `intl_messages_all.dart` 文件，它引入了所有的信息文件。

    ```console
    $ dart run intl_translation:generate_from_arb \
        --output-dir=lib/l10n --no-use-deferred-loading \
        lib/main.dart lib/l10n/intl_*.arb
    ```

    ***Windows doesn't support file name wildcarding.***
    Instead, list the .arb files that were generated by the
    `intl_translation:extract_to_arb` command.

    **Windows 系统不支持文件名通配符**。
    列出的 `.arb` 文件是由 `intl_translation:extract_to_arb` 命令生成的。

    ```console
    $ dart run intl_translation:generate_from_arb \
        --output-dir=lib/l10n --no-use-deferred-loading \
        lib/main.dart \
        lib/l10n/intl_en.arb lib/l10n/intl_fr.arb lib/l10n/intl_messages.arb
    ```

    The `DemoLocalizations` class uses the generated
    `initializeMessages()` function
    (defined in `intl_messages_all.dart`)
    to load the localized messages and `Intl.message()`
    to look them up.

    `DemoLocalizations` 类使用生成的 `initializeMessages()` 方法
    （该方法定义在 `intl_messages_all.dart` 文件）
    来加载本地化的信息，然后使用 `Intl.message()` 来查阅这些本地化的信息。

## More information

## 更多信息

If you learn best by reading code,
check out the following examples.

如果你希望通过代码进行学习，你可以查看以下的示例。

* [`minimal`][]<br>
  The `minimal` example is designed to be as
  simple as possible.

  [最简示例][`minimal`]<br>
  最简展示了如果以最简单的方式实现国际化。

* [`intl_example`][]<br>
  uses APIs and tools provided by the [`intl`][] package.

  [`intl` 示例][`intl_example`]<br>
  利用 [`intl`][] package 实现国际化的示例。

If Dart's `intl` package is new to you,
check out [Using the Dart intl tools](#dart-tools).

如果你还未使用过 `intl` package，你可以阅读 [如何使用 Dart 的 intl 工具](#dart-tools)。

[`intl_example`]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/intl_example
[`minimal`]: {{site.repo.this}}/tree/{{site.branch}}/examples/internationalization/minimal

