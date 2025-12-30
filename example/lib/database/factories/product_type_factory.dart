import 'package:fluttersdk_magic/fluttersdk_magic.dart';

import '../../app/models/product_type.dart';

/// ProductTypeFactory
///
/// Generates fake ProductType instances for seeding and testing.
class ProductTypeFactory extends Factory<ProductType> {
  @override
  ProductType newInstance() => ProductType();

  @override
  Map<String, dynamic> definition() {
    return {
      'name': faker.person.name(),
      'email': faker.internet.email(),
      // Add more attributes here
    };
  }

  // Custom States
  // 
  // ProductTypeFactory inactive() {
  //   return state({'is_active': false}) as ProductTypeFactory;
  // }
}
