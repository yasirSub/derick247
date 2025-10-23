# API Configuration Guide

This guide explains how to configure your Flutter app to work with the Comisionista247 API based on the Postman collection.

## 1. Update API Configuration

Edit `lib/config/api_config.dart` and update the following values:

```dart
class ApiConfig {
  // Replace with your actual API base URL
  static const String baseUrl = 'https://your-actual-api-domain.com/api/';
  
  // Replace with your actual API key
  static const String apiKey = 'your-actual-api-key-here';
  
  // ... rest of the configuration
}
```

## 2. API Endpoints Available

Based on the Postman collection, the following endpoints are now supported:

### Authentication
- `POST /login` - User login (form-data)
- `POST /register` - User registration (form-data)
- `POST /logout` - User logout
- `POST /resend-verification` - Resend verification email
- `GET /profile` - Get user profile
- `POST /profile` - Update user profile (form-data)

### Products & Categories
- `GET /` - Home data with products (root endpoint)
- `GET /product/{id}` - Product details
- `GET /categories` - Get all categories

### Cart Management
- `GET /cart` - Get cart items
- `POST /cart` - Add item to cart (form-data)
- `POST /cart/{id}` - Update cart item quantity (form-data with _method=PUT)
- `DELETE /cart/{id}` - Remove item from cart

### Orders
- `GET /orders` - Get user orders
- `GET /orders/{id}` - Get order details

### Referral System
- `GET /referral-info/{id}` - Get referral information for product
- `POST /refer-friend` - Refer a friend (form-data)

### Location Services
- `GET /locations` - Get countries
- `GET /locations?country_id={id}` - Get states for country
- `GET /locations?states={id}` - Get cities for state

### Dropshipping Products
- `GET /dropshipping-product` - Get dropshipping products
- `POST /dropshipping-product/update/` - Add dropshipping product
- `GET /dropshipping-product/{id}` - Get dropshipping product details
- `POST /dropshipping-product/{id}` - Update dropshipping product (form-data with _method=PUT)
- `DELETE /dropshipping-product/{id}` - Delete dropshipping product

### Vendor Products
- `GET /vendor-product` - Get vendor products
- `POST /vendor-product` - Add vendor product (form-data)
- `GET /vendor-product/{id}` - Get vendor product details
- `POST /vendor-product/{id}` - Update vendor product (form-data with _method=PUT)
- `DELETE /vendor-product/{id}` - Delete vendor product

## 3. Data Models

The following data models have been created/updated:

- `Product` - Product information
- `Category` - Product categories
- `User` - User profile and authentication
- `Cart` - Shopping cart items
- `Order` - Order information
- `Location` - Countries, states, cities
- `ReferralInfo` - Referral commission information
- `ReferralFriend` - Referred friends

## 4. Authentication Flow

1. **Login**: Send email/password as form-data to `/login`
2. **Token**: Extract `access_token` from response
3. **Authorization**: Include token in `Authorization: Bearer {token}` header
4. **Logout**: Call `/logout` and clear token

## 5. Form Data vs JSON

Most POST requests use form-data instead of JSON:
- Authentication (login, register, logout)
- Cart operations
- Profile updates
- Product management
- Referral submissions

Only GET requests and some specific endpoints use JSON.

## 6. Error Handling

The API service includes automatic error handling:
- 401 errors clear the auth token
- Request/response logging for debugging
- Timeout handling (30 seconds)

## 7. Usage Example

```dart
// Initialize API service
ApiService().initialize();

// Login
final response = await ApiService().login('user@example.com', 'password');
if (response.statusCode == 200) {
  final token = response.data['access_token'];
  ApiService().setAuthToken(token);
}

// Get products
final homeResponse = await ApiService().getHomeData(page: 1);
final products = homeResponse.data['data']['data'] as List;
```

## 8. Testing

Use the provided `lib/examples/api_usage_example.dart` file to test all API endpoints and see proper usage patterns.

## 9. Important Notes

- Always use the correct headers (`x-api-key` for all requests)
- Most POST requests require form-data format
- Update requests use `_method=PUT` in form-data
- Authentication token is automatically included in requests after login
- The API uses pagination for list endpoints

## 10. Next Steps

1. Update `ApiConfig` with your actual API URL and key
2. Test authentication flow
3. Implement UI screens using the API service
4. Handle loading states and error messages
5. Add proper validation for form inputs
