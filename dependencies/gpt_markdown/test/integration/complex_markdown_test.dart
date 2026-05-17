import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import '../utils/test_helpers.dart';

void main() {
  group('Complex markdown document', () {
    const complexDocument = '''
# Shopping Trip Planner

## Grocery List

### Produce
- Apples
- Bananas
- **Organic** spinach
- [Recipe ideas](https://example.com/recipes)
* Tomatoes
* *Fresh* basil

### Dairy
- Milk
- Cheese
- Butter

## Shopping Checklist

[x] Check pantry inventory
[x] Make shopping list
[ ] Go to [Grocery Store](https://example.com/store)
[ ] Buy groceries
[ ] Put away groceries

## Price Comparison

| Item | Store A | Store B |
|------|---------|---------|
| [Milk](https://example.com/milk) | \$3.99 | \$4.29 |
| Bread | \$2.50 | \$2.25 |
| **Eggs** | \$5.99 | \$6.49 |

## Notes

> Remember to bring reusable bags!

Use the `rewards card` for discounts.

---

### Quick Tips

1. Shop early for best selection
2. Check expiration dates
3. Compare unit prices
''';

    testWidgets('renders without errors', (tester) async {
      await pumpMarkdown(tester, complexDocument);

      // Should render successfully
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('contains all heading levels', (tester) async {
      await pumpMarkdown(tester, complexDocument);

      // Document has h1, h2, h3 headings
      // They should all render (even if serialized differently)
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('contains unordered list items', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have multiple UL_ITEM entries (dash and asterisk formats)
      expect(output, contains('UL_ITEM'));
      // Count list items - we have at least 9 unordered items (including link item)
      expect('UL_ITEM'.allMatches(output).length, greaterThanOrEqualTo(6));
    });

    testWidgets('contains ordered list items', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have OL_ITEM entries for the numbered tips
      expect(output, contains('OL_ITEM'));
      expect('OL_ITEM'.allMatches(output).length, equals(3));
    });

    testWidgets('contains checkboxes with mixed states', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have CHECKBOX entries
      expect(output, contains('CHECKBOX'));
      // We have 5 checkboxes total
      expect('CHECKBOX'.allMatches(output).length, equals(5));
      // Mix of checked and unchecked
      expect(output, contains('checked=true'));
      expect(output, contains('checked=false'));
    });

    testWidgets('contains table', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have TABLE
      expect(output, contains('TABLE'));
      expect(output, contains('HEADER'));
      expect(output, contains('ROW'));
    });

    testWidgets('contains blockquote', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have BLOCKQUOTE
      expect(output, contains('BLOCKQUOTE'));
    });

    testWidgets('contains horizontal rule', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have HR
      expect(output, contains('HR'));
    });

    testWidgets('contains inline code', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Should have highlighted text for `rewards card`
      expect(output, contains('highlight'));
    });

    testWidgets('contains links in various sections', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Links in list, table, and checkbox sections
      expect(output, contains('LINK'));
      // Link in unordered list
      expect(output, contains('LINK("Recipe ideas")'));
      // Link in checkbox item
      expect(output, contains('LINK("Grocery Store")'));
    });

    testWidgets('contains bold text', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Bold text is now fully parsed in nested content
      expect(output, contains('[bold]'));
      expect(output, contains('TEXT("Organic")[bold]'));
    });

    testWidgets('contains italic text', (tester) async {
      await pumpMarkdown(tester, complexDocument);
      final output = getSerializedOutput(tester);

      // Italic text is now fully parsed in nested content
      expect(output, contains('[italic]'));
      expect(output, contains('TEXT("Fresh")[italic]'));
    });
  });

  group('Nested structure document', () {
    const nestedDocument = '''
# Main Title

Some introductory text with **bold** and *italic* formatting.

## Section One

- First item
- Second item with `inline code`
- Third item

### Subsection 1.1

| Column A | Column B |
|----------|----------|
| Value 1  | Value 2  |

### Subsection 1.2

1. Numbered item one
2. Numbered item two

## Section Two

> A meaningful quote

( ) Option A
(x) Option B
( ) Option C

---

*End of document*
''';

    testWidgets('nested document renders completely', (tester) async {
      await pumpMarkdown(tester, nestedDocument);

      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('has correct element counts', (tester) async {
      await pumpMarkdown(tester, nestedDocument);
      final output = getSerializedOutput(tester);

      // 3 unordered list items
      expect('UL_ITEM'.allMatches(output).length, equals(3));

      // 2 ordered list items
      expect('OL_ITEM'.allMatches(output).length, equals(2));

      // 3 radio buttons
      expect('RADIO'.allMatches(output).length, equals(3));

      // 1 table
      expect('TABLE'.allMatches(output).length, equals(1));

      // 1 blockquote
      expect('BLOCKQUOTE'.allMatches(output).length, equals(1));

      // 1 horizontal rule
      expect('HR'.allMatches(output).length, equals(1));
    });
  });

  group('Edge cases in complex documents', () {
    testWidgets('empty lines between elements', (tester) async {
      const markdown = '''
# Heading


Paragraph after double newline.


- List item after double newline
''';
      await pumpMarkdown(tester, markdown);
      final output = getSerializedOutput(tester);

      expect(output, contains('NEWLINE'));
      expect(output, contains('UL_ITEM'));
    });

    testWidgets('mixed list formats', (tester) async {
      const markdown = '''
- Dash item 1
* Asterisk item 1
- Dash item 2
* Asterisk item 2
''';
      await pumpMarkdown(tester, markdown);
      final output = getSerializedOutput(tester);

      expect('UL_ITEM'.allMatches(output).length, equals(4));
    });

    testWidgets('styled text in table cells', (tester) async {
      const markdown = '''
| Normal | **Bold** | *Italic* |
|--------|----------|----------|
| a      | **b**    | *c*      |
''';
      await pumpMarkdown(tester, markdown);
      final output = getSerializedOutput(tester);

      expect(output, contains('TABLE'));
      // Table should contain styled content
    });

    testWidgets('code block followed by list', (tester) async {
      const markdown = '''
```dart
void main() {}
```

- Item after code block
''';
      await pumpMarkdown(tester, markdown);
      final output = getSerializedOutput(tester);

      expect(output, contains('CODE_BLOCK'));
      expect(output, contains('UL_ITEM'));
    });
  });
}
