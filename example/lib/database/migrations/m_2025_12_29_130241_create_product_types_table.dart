import 'package:magic/magic.dart';

/// Migration: 2025_12_29_130241_create_product_types_table
///
/// Creates the product_type table.
class CreateProductTypesTable extends Migration {
  @override
  String get name => '2025_12_29_130241_create_product_types_table';

  @override
  void up() {
    Schema.create('product_type', (Blueprint table) {
      table.id();
      // Add your columns here
      table.timestamps();
    });
  }

  @override
  void down() {
    Schema.dropIfExists('product_type');
  }
}
