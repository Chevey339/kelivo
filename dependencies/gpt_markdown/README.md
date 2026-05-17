# 📦 GPT Markdown & LaTeX for Flutter

[![Pub Version](https://img.shields.io/pub/v/gpt_markdown)](https://pub.dev/packages/gpt_markdown) [![Pub Likes](https://img.shields.io/pub/likes/gpt_markdown)](https://pub.dev/packages/gpt_markdown) [![Pub Points](https://img.shields.io/pub/points/gpt_markdown)](https://pub.dev/packages/gpt_markdown) [![GitHub](https://img.shields.io/badge/github-gpt__markdown-blue?logo=github)](https://github.com/Infinitix-LLC/gpt_markdown)

A Flutter package for rendering rich Markdown and LaTeX in your app — built for AI outputs like ChatGPT and Gemini. Drop-in replacement for flutter_markdown with full LaTeX support and better AI integration.

🌐 [gptmarkdown.com](https://gptmarkdown.com) · 📖 [Docs](https://gptmarkdown.com/docs) · 🎮 [Live Playground](https://gptmarkdown.com/playground)

---

## 🚀 Why Use GPT Markdown?

- **Optimized for AI Outputs**: Render ChatGPT and Gemini responses flawlessly in your Flutter apps.
- **LaTeX out of the box**: No extra setup — math rendering works from the first line.
- **Rich Customization**: Easily apply custom styles using Flutter widgets like `TextStyle`.
- **Selectable Content**: Pass `selectable: true` to make text highlightable and copyable on desktop and web.
- **Seamless Integration**: Works out of the box with minimal setup.

---

## Supported Markdown & LaTeX Features
| ✨ Feature  | ✅ Supported | 🔜 Upcoming |
| --- | --- | --- |
| 💻 Code Block | ✅ |  |
| 📊 Table | ✅ |  |
| 📝 Heading | ✅ |  |
| 📌 Unordered List | ✅ |  |
| 📋 Ordered List | ✅ |  |
| 🔘 Radio Button | ✅ |  |
| ☑️ Check Box | ✅ |  |
| ➖ Horizontal Line | ✅ |  |
| 🔢 Latex Math | ✅ |  |
| ↩️ Indent | ✅ |
| 💬 BlockQuote | ✅ |
| 🖼️ Image | ✅ |
| ✨ Highlighted Text | ✅ |
| ✂️ Strike Text | ✅ |
| 🔵 Bold Text | ✅ |
| 📜 Italic Text | ✅ |
| 🔗 Links | ✅ |
| 📱 Selectable | ✅ |
| 🧩 Custom components | ✅ |  |
| 📎 Underline | ✅ |  |

## ✨ Key Features

Render a wide variety of content with full Markdown and LaTeX support, including:

- List 
```
- Unordered list item
1. Ordered list item
```

- Horizontal line
```
---
```

- Links 
```
[<text here>](<href>)
```

- Images with size 
```
![<width>x<height> someText](url)
```
- Table

```
| Name  | Roll |
|-------|------|
| sohag | 1    |

```

| Name  | Roll |
|-------|------|
| sohag | 1    |

- ~~Striked text~~
```
~~striked text~~
```

- **Bold text**
```
**Bold text**
```

- *Italic text*
```
*Italic text*
```

- <u>Underline text</u>
```
<u>Underline text</u>
```

- heading texts 

```
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

- Latex formula `\(\frac a b\)` or `\[\frac ab\]`
```
\(\frac a b\)
```

- Radio button and checkbox

```
() Unchecked radio
(x) Checked radio
[] Unchecked checkbox
[x] Checked checkbox
```

- Enable text selection on desktop and web:

```dart
GptMarkdown(markdownText, selectable: true)
```

---

## 🛠️ Getting Started

Run this command:
```
flutter pub add gpt_markdown 
```

## 📖 Usage

Check the documentation [here.](https://gptmarkdown.com/docs)

```dart
import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

GptMarkdown(
  r'''
## Hello from gpt_markdown!

Render **bold**, *italic*, ~~strikethrough~~, `inline code`, and <u>underline</u>.

Inline LaTeX: \( E = mc^2 \) and block math:

\[
x = \frac{-b \pm \sqrt{b^2 - 4ac}}{2a}
\]

| Name  | Score |
|-------|-------|
| Alice | 98    |
| Bob   | 87    |

- [x] Task complete
- [ ] Task pending
  ''',
  onLinkTap: (url, title) => debugPrint('Tapped: $url'),
)
```

## 💡 ChatGPT Response Examples

```markdown
## ChatGPT Response

Welcome to ChatGPT! Below is an example of a response with Markdown and LaTeX code:

### Markdown Example

You can use Markdown to format text easily. Here are some examples:

- **Bold Text**: **This text is bold**
- *Italic Text*: *This text is italicized*
- [Link](https://www.example.com): [This is a link](https://www.example.com)
- Lists:
  1. Item 1
  2. Item 2
  3. Item 3

### LaTeX Example

You can also use LaTeX for mathematical expressions. Here's an example:

- **Equation**: \( f(x) = x^2 + 2x + 1 \)
- **Integral**: \( \int_{0}^{1} x^2 \, dx \)
- **Matrix**:

\[
\begin{bmatrix}
1 & 2 & 3 \\
4 & 5 & 6 \\
7 & 8 & 9
\end{bmatrix}
\]

### Conclusion

Markdown and LaTeX can be powerful tools for formatting text and mathematical expressions in your Flutter app. If you have any questions or need further assistance, feel free to ask!
```
### Output from gpt_markdown

<img width="614" alt="Screenshot 2024-02-15 at 4 13 59 AM" src="https://github.com/saminsohag/flutter_packages/assets/59507062/8f4a4068-a12c-45d1-a954-ebaf3822e754">

If you're using flutter_markdown and need more customization or LaTeX support, gpt_markdown is a great alternative.

---

⭐ If you find this package helpful, please give it a like on [pub.dev](https://pub.dev/packages/gpt_markdown)! Your support means a lot! ⭐

## 🔗 Additional Information

- 🌐 [Website](https://gptmarkdown.com)
- 📖 [Documentation](https://gptmarkdown.com/docs)
- 🎮 [Live playground](https://gptmarkdown.com/playground)
- 📦 [pub.dev](https://pub.dev/packages/gpt_markdown)
- 🐛 [Issue tracker](https://github.com/Infinitix-LLC/gpt_markdown/issues)
- 💬 [Publisher](https://infinitix.tech)
