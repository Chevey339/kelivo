import 'package:integration_test/integration_test.dart';

import '../test/features/world_book/world_book_page_test.dart' as world_book;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  world_book.main();
}
