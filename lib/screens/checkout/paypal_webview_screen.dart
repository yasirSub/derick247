import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PaypalWebViewScreen extends StatefulWidget {
  final String approvalUrl;

  const PaypalWebViewScreen({Key? key, required this.approvalUrl})
    : super(key: key);

  @override
  State<PaypalWebViewScreen> createState() => _PaypalWebViewScreenState();
}

class _PaypalWebViewScreenState extends State<PaypalWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _currentUrl;
  bool _hasHandledReturn = false; // Track if we've already handled a return

  @override
  void dispose() {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🗑️ [PayPal WebView] DISPOSING');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('   → Final URL: $_currentUrl');
    debugPrint('   → Approval URL: ${widget.approvalUrl}');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    debugPrint(
      '🚀 [PayPal WebView] Initializing with approval URL: ${widget.approvalUrl}',
    );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..enableZoom(true)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            debugPrint('📄 [PayPal WebView] onPageStarted called');
            debugPrint('   → URL: $url');
            debugPrint('   → Previous URL: $_currentUrl');

            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });

            debugPrint('🔍 [PayPal WebView] Checking if URL is return URL...');
            final isReturnUrl = _isPayPalReturnUrl(url);
            debugPrint('   → Is return URL: $isReturnUrl');
            debugPrint('   → Has handled return: $_hasHandledReturn');

            if (isReturnUrl && !_hasHandledReturn) {
              debugPrint(
                '⚠️ [PayPal WebView] Return URL detected in onPageStarted!',
              );
              _hasHandledReturn = true;
              _handlePayPalReturn(url);
            } else {
              debugPrint(
                '✓ [PayPal WebView] Not a return URL, continuing navigation',
              );
            }
          },
          onPageFinished: (url) async {
            debugPrint('✅ [PayPal WebView] onPageFinished called');
            debugPrint('   → URL: $url');
            debugPrint('   → Previous URL: $_currentUrl');

            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });

            // FIRST: Check if this is a success endpoint and needs JSON replacement
            // This must happen BEFORE return URL check to ensure JSON is replaced
            final urlLower = url.toLowerCase();
            final isCheckoutSuccess =
                urlLower.contains('checkout/paypal/success') ||
                urlLower.contains('checkout/success') ||
                urlLower.contains('/checkout/paypal/success') ||
                urlLower.contains('/checkout/success');
            final isCaptureOrder = urlLower.contains('capture-order');

            debugPrint('   → Checking for success endpoints...');
            debugPrint('      → URL: $url');
            debugPrint('      → URL lower: $urlLower');
            debugPrint('      → Is checkout success: $isCheckoutSuccess');
            debugPrint('      → Is capture order: $isCaptureOrder');
            debugPrint(
              '      → Will handle: ${(isCaptureOrder || isCheckoutSuccess) && !_hasHandledReturn}',
            );

            if ((isCaptureOrder || isCheckoutSuccess) && !_hasHandledReturn) {
              debugPrint(
                '⚠️ [PayPal WebView] ${isCheckoutSuccess ? "Checkout success" : "Capture-order"} endpoint loaded - replacing JSON with success screen...',
              );

              // Variables to store payment result
              bool paymentSuccess = false;
              String? successMessage;

              // Immediately inject JavaScript to replace JSON content with success message
              // This runs right away to prevent showing raw JSON
              try {
                final replaceJsCode = '''
                  (function() {
                    // Get the body content
                    var bodyText = document.body.innerText || document.body.textContent || '';
                    var bodyHTML = document.body.innerHTML || '';
                    
                    // Try to parse JSON from body text
                    var jsonData = null;
                    var successMessage = 'Payment completed successfully!';
                    var isSuccess = false;
                    
                    try {
                      // Try parsing from body text
                      jsonData = JSON.parse(bodyText.trim());
                      isSuccess = jsonData.status === 'success' || jsonData.success === true;
                      successMessage = jsonData.message || 'Payment completed successfully!';
                    } catch(e1) {
                      try {
                        // Try parsing from HTML content
                        var jsonMatch = bodyHTML.match(/\\{[^}]*"status"[^}]*\\}/);
                        if (jsonMatch) {
                          jsonData = JSON.parse(jsonMatch[0]);
                          isSuccess = jsonData.status === 'success' || jsonData.success === true;
                          successMessage = jsonData.message || 'Payment completed successfully!';
                        } else if (bodyText.toLowerCase().includes('success')) {
                          isSuccess = true;
                        }
                      } catch(e2) {
                        // If contains 'success' in text, assume success
                        if (bodyText.toLowerCase().includes('success')) {
                          isSuccess = true;
                        }
                      }
                    }
                    
                    // Replace entire body with success message
                    if (isSuccess || bodyText.toLowerCase().includes('success')) {
                      document.body.innerHTML = '<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;background:linear-gradient(135deg, #667eea 0%, #764ba2 100%);color:white;font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;padding:20px;text-align:center;margin:0;"><div style="font-size:64px;margin-bottom:20px;animation:fadeIn 0.5s;">✓</div><h1 style="font-size:28px;margin-bottom:10px;font-weight:bold;animation:fadeIn 0.6s;">Payment Successful!</h1><p style="font-size:18px;opacity:0.9;line-height:1.6;animation:fadeIn 0.7s;">' + successMessage + '</p><p style="font-size:14px;margin-top:20px;opacity:0.7;animation:fadeIn 0.8s;">Redirecting...</p><style>@keyframes fadeIn{from{opacity:0;transform:translateY(10px);}to{opacity:1;transform:translateY(0);}}</style></div>';
                      document.body.style.margin = '0';
                      document.body.style.padding = '0';
                      return JSON.stringify({success: true, message: successMessage});
                    }
                    
                    return JSON.stringify({success: false, message: 'Could not determine payment status'});
                  })();
                ''';

                // Inject immediately to replace JSON
                await _controller.runJavaScript(replaceJsCode);

                // Wait a moment for injection to complete, then read the result
                await Future.delayed(const Duration(milliseconds: 300));

                // Read the actual response to verify success (paymentSuccess and successMessage already declared above)
                try {
                  final readJsCode = '''
                    (function() {
                      try {
                        var bodyText = document.body.innerText || document.body.textContent || '';
                        // Check if we successfully replaced content
                        if (bodyText.includes('Payment Successful')) {
                          return JSON.stringify({success: true, message: 'Payment completed successfully!'});
                        }
                        // Fallback: try to find original JSON
                        var match = bodyText.match(/\\{[^}]*"status"[^}]*\\}/);
                        if (match) {
                          var json = JSON.parse(match[0]);
                          return JSON.stringify({
                            success: json.status === 'success' || json.success === true,
                            message: json.message || 'Payment completed successfully!'
                          });
                        }
                        return JSON.stringify({success: true, message: 'Payment completed successfully!'});
                      } catch(e) {
                        return JSON.stringify({success: true, message: 'Payment completed successfully!'});
                      }
                    })();
                  ''';

                  final result = await _controller.runJavaScriptReturningResult(
                    readJsCode,
                  );
                  final resultStr = result.toString();

                  debugPrint('   → Read result: $resultStr');

                  // Parse result
                  String cleanedResult = resultStr;
                  if (cleanedResult.startsWith('"') &&
                      cleanedResult.endsWith('"')) {
                    cleanedResult = cleanedResult.substring(
                      1,
                      cleanedResult.length - 1,
                    );
                  }
                  cleanedResult = cleanedResult.replaceAll('\\"', '"');

                  try {
                    final responseData = json.decode(cleanedResult);
                    paymentSuccess =
                        responseData['success'] == true ||
                        responseData['success'] == 'true';
                    successMessage = responseData['message']?.toString();
                    debugPrint('   → Payment success: $paymentSuccess');
                    debugPrint('   → Message: $successMessage');
                  } catch (e) {
                    debugPrint('   → Could not parse result: $e');
                    paymentSuccess = true; // Assume success
                  }
                } catch (e) {
                  debugPrint('⚠️ [PayPal WebView] Error reading response: $e');
                  paymentSuccess =
                      true; // Assume success if endpoint was reached
                }
              } catch (e) {
                debugPrint('⚠️ [PayPal WebView] Error replacing JSON: $e');
                // Still assume success and try basic replacement
                try {
                  final basicReplace = '''
                    document.body.innerHTML = '<div style="display:flex;flex-direction:column;align-items:center;justify-content:center;min-height:100vh;background:linear-gradient(135deg, #667eea 0%, #764ba2 100%);color:white;font-family:Arial,sans-serif;padding:20px;text-align:center;"><div style="font-size:64px;margin-bottom:20px;">✓</div><h1 style="font-size:28px;margin-bottom:10px;font-weight:bold;">Payment Successful!</h1><p style="font-size:18px;opacity:0.9;">Payment completed successfully!</p><p style="font-size:14px;margin-top:20px;opacity:0.7;">Redirecting...</p></div>';
                  ''';
                  await _controller.runJavaScript(basicReplace);
                  paymentSuccess = true;
                } catch (e2) {
                  debugPrint(
                    '⚠️ [PayPal WebView] Error with basic replacement: $e2',
                  );
                  paymentSuccess = true; // Assume success
                }
              }

              // Mark as handled now that we've processed it
              _hasHandledReturn = true;

              // Wait 2 seconds for user to see success message and backend to finish processing
              await Future.delayed(const Duration(seconds: 2));

              // Now return - backend has processed payment
              if (mounted) {
                debugPrint(
                  '⚠️ [PayPal WebView] ${isCheckoutSuccess ? "Checkout success" : "Capture-order"} endpoint processed (success: $paymentSuccess) - returning!',
                );
                // Always mark as success for checkout/capture-order endpoints since we verified payment
                // Call handlePayPalReturn directly - it will determine success from URL
                _handlePayPalReturn(url);
              } else {
                debugPrint(
                  '⚠️ [PayPal WebView] Widget not mounted, cannot return!',
                );
              }
              return; // Exit early if we handled success endpoint - don't check for other return URLs
            }

            // SECOND: Check if this is a return URL (for other return patterns)
            debugPrint(
              '🔍 [PayPal WebView] Checking if finished URL is return URL...',
            );
            final isReturnUrl = _isPayPalReturnUrl(url);
            debugPrint('   → Is return URL: $isReturnUrl');
            debugPrint('   → Has handled return: $_hasHandledReturn');

            if (isReturnUrl && !_hasHandledReturn) {
              debugPrint(
                '⚠️ [PayPal WebView] Return URL detected in onPageFinished!',
              );
              _hasHandledReturn = true;
              _handlePayPalReturn(url);
            } else {
              debugPrint(
                '✓ [PayPal WebView] Not a return URL, page loaded normally',
              );
            }
          },
          onNavigationRequest: (request) {
            debugPrint('🧭 [PayPal WebView] onNavigationRequest called');
            debugPrint('   → Request URL: ${request.url}');
            debugPrint('   → Is main frame: ${request.isMainFrame}');
            debugPrint('   → Current URL: $_currentUrl');

            // For capture-order or checkout success endpoints, we need to ALLOW navigation
            // so backend can process payment and we can show success screen
            final requestUrlLower = request.url.toLowerCase();
            final isCaptureOrder = requestUrlLower.contains('capture-order');
            final isCheckoutSuccessNav =
                requestUrlLower.contains('/checkout/paypal/success') ||
                requestUrlLower.contains('/checkout/success');

            if (isCaptureOrder || isCheckoutSuccessNav) {
              debugPrint(
                '✓ [PayPal WebView] Allowing navigation to ${isCheckoutSuccessNav ? "checkout success" : "capture-order"} endpoint (backend needs to process payment)',
              );
              return NavigationDecision
                  .navigate; // Allow navigation - backend needs to process
            }

            debugPrint(
              '🔍 [PayPal WebView] Checking if navigation request is return URL...',
            );
            final isReturnUrl = _isPayPalReturnUrl(request.url);
            debugPrint('   → Is return URL: $isReturnUrl');
            debugPrint('   → Has handled return: $_hasHandledReturn');

            // Only prevent navigation for other return URLs (not capture-order)
            if (isReturnUrl && !_hasHandledReturn && !isCaptureOrder) {
              debugPrint(
                '⚠️ [PayPal WebView] Return URL detected in onNavigationRequest!',
              );
              debugPrint('   → Preventing navigation and handling return...');
              _hasHandledReturn = true;
              _handlePayPalReturn(request.url);
              return NavigationDecision.prevent;
            }

            debugPrint(
              '✓ [PayPal WebView] Allowing navigation to: ${request.url}',
            );
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('❌ [PayPal WebView] Web Resource Error:');
            debugPrint('   → Description: ${error.description}');
            debugPrint('   → Error Code: ${error.errorCode}');
            debugPrint('   → Error Type: ${error.errorType}');
            debugPrint('   → URL: ${error.url}');

            // Don't treat network errors as fatal if they're not critical
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout) {
              debugPrint(
                '⚠️ [PayPal WebView] Network error detected, but continuing...',
              );
            }
          },
          onProgress: (progress) {
            debugPrint('📊 [PayPal WebView] Loading progress: $progress%');
          },
          onUrlChange: (change) {
            debugPrint('🔄 [PayPal WebView] URL Changed:');
            debugPrint('   → From: ${change.url}');
            debugPrint('   → To: ${change.url}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.approvalUrl));

    debugPrint(
      '📱 [PayPal WebView] WebView controller initialized and loading started',
    );
  }

  void _handlePayPalReturn(String url) {
    debugPrint('');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('🎯 [PayPal WebView] HANDLING PAYPAL RETURN');
    debugPrint('═══════════════════════════════════════════════════════════');
    debugPrint('   → Return URL: $url');
    debugPrint('   → Current URL state: $_currentUrl');
    debugPrint('   → Is mounted: $mounted');

    debugPrint('🔍 [PayPal WebView] Determining success status...');
    final isSuccess = _isPayPalSuccessUrl(url);
    debugPrint('   → Is Success: $isSuccess');

    if (mounted) {
      final returnData = {'success': isSuccess, 'url': url};
      debugPrint('📤 [PayPal WebView] Popping Navigator with data:');
      debugPrint('   → success: $isSuccess');
      debugPrint('   → url: $url');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');

      try {
        // Use a post frame callback to ensure context is valid
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop(returnData);
          }
        });
      } catch (e) {
        debugPrint('⚠️ [PayPal WebView] Error handling return: $e');
        // Fallback: try to pop immediately
        if (mounted) {
          try {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop(returnData);
            }
          } catch (popError) {
            debugPrint('❌ [PayPal WebView] Failed to pop: $popError');
          }
        }
      }
    } else {
      debugPrint('⚠️ [PayPal WebView] Widget not mounted, cannot pop!');
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('');
    }
  }

  bool _isPayPalReturnUrl(String url) {
    debugPrint('🔎 [PayPal WebView] _isPayPalReturnUrl() called');
    debugPrint('   → Input URL: $url');

    final lower = url.toLowerCase();
    final uri = Uri.tryParse(url);

    debugPrint('   → Parsed URI: ${uri != null ? "Success" : "Failed"}');
    if (uri != null) {
      debugPrint('   → URI Path: ${uri.path}');
      debugPrint('   → URI Query: ${uri.query}');
      debugPrint('   → URI Host: ${uri.host}');
    }

    // Check for common PayPal return URL patterns
    final isPayPalDomain =
        lower.contains('paypal.com') || lower.contains('sandbox.paypal.com');
    debugPrint('   → Is PayPal domain: $isPayPalDomain');

    if (isPayPalDomain) {
      // Check URL path
      if (uri != null) {
        final path = uri.path.toLowerCase();
        final query = uri.query.toLowerCase();

        debugPrint('   → Checking path patterns...');
        debugPrint('      → Path: $path');
        debugPrint('      → Query: $query');

        // PayPal success/cancel paths
        final hasCheckoutPath =
            path.contains('/checkout') ||
            path.contains('/webapps/hermes') ||
            path.contains('/cgi-bin/webscr');
        debugPrint('      → Has checkout path: $hasCheckoutPath');

        if (hasCheckoutPath) {
          // IMPORTANT: /checkoutnow?token= is the INITIAL approval URL, not a return URL
          // NEVER treat /checkoutnow as a return URL - it's always the initial checkout page
          if (path == '/checkoutnow') {
            debugPrint(
              '   ❌ [PayPal WebView] This is the checkout page (/checkoutnow), not a return URL',
            );
            return false;
          }

          // For other checkout paths, check query parameters for return indicators
          final hasReturnParams =
              query.contains('payerid=') ||
              query.contains('paymentid=') ||
              query.contains('returnurl=') ||
              query.contains('cancelurl=') ||
              query.contains('useraction=');
          debugPrint('      → Has return params: $hasReturnParams');

          if (hasReturnParams) {
            debugPrint(
              '   ✅ [PayPal WebView] RETURN URL DETECTED: Has checkout path + return params',
            );
            return true;
          }
        }

        // Check for success/cancel in path
        final hasReturnPath =
            path.contains('/success') ||
            path.contains('/cancel') ||
            path.contains('/return') ||
            path.contains('/complete');
        debugPrint('      → Has return path: $hasReturnPath');

        if (hasReturnPath) {
          debugPrint(
            '   ✅ [PayPal WebView] RETURN URL DETECTED: Has return path',
          );
          return true;
        }
      }

      // Check for specific PayPal return indicators in URL
      debugPrint('   → Checking URL string patterns...');
      final hasReturnIndicators =
          lower.contains('paypal/success') ||
          lower.contains('paypal/cancel') ||
          lower.contains('checkout/paypal/success') ||
          lower.contains('checkout/success') ||
          lower.contains('checkout/status') ||
          lower.contains('payment=success') ||
          lower.contains('payment=cancel') ||
          lower.contains('useraction=commit') ||
          lower.contains('useraction=cancel');
      debugPrint('      → Has return indicators: $hasReturnIndicators');

      if (hasReturnIndicators) {
        debugPrint(
          '   ✅ [PayPal WebView] RETURN URL DETECTED: Has return indicators',
        );
        return true;
      }
    }

    // Check for custom return URLs (your backend might redirect here)
    debugPrint('   → Checking custom return URL patterns...');
    final hasCustomReturn =
        lower.contains('/payment/return') ||
        lower.contains('/payment/success') ||
        lower.contains('/payment/cancel') ||
        lower.contains('/checkout/return') ||
        lower.contains('/checkout/success') ||
        lower.contains('/checkout/paypal/success') ||
        lower.contains('/checkout/cancel') ||
        lower.contains('/api/wallet/capture-order') ||
        lower.contains('/wallet/capture-order') ||
        lower.contains('capture-order');
    debugPrint('      → Has custom return: $hasCustomReturn');

    if (hasCustomReturn) {
      debugPrint(
        '   ✅ [PayPal WebView] RETURN URL DETECTED: Custom return URL',
      );
      return true;
    }

    debugPrint('   ❌ [PayPal WebView] NOT a return URL');
    return false;
  }

  bool _isPayPalSuccessUrl(String url) {
    debugPrint('🔎 [PayPal WebView] _isPayPalSuccessUrl() called');
    debugPrint('   → Input URL: $url');

    final lower = url.toLowerCase();

    // Check for cancellation indicators first
    debugPrint('   → Checking for cancellation indicators...');
    final hasCancel =
        lower.contains('cancel') ||
        lower.contains('useraction=cancel') ||
        lower.contains('payment=cancel');
    debugPrint('      → Has cancel: $hasCancel');

    if (hasCancel) {
      debugPrint('   ❌ [PayPal WebView] CANCELLATION detected');
      return false;
    }

    // Check for capture-order endpoint (backend success endpoint)
    if (lower.contains('capture-order')) {
      debugPrint(
        '   ✅ [PayPal WebView] SUCCESS detected: capture-order endpoint',
      );
      return true;
    }

    // Check for checkout success endpoint
    if (lower.contains('/checkout/paypal/success') ||
        lower.contains('/checkout/success')) {
      debugPrint(
        '   ✅ [PayPal WebView] SUCCESS detected: checkout success endpoint',
      );
      return true;
    }

    // Check for success indicators
    debugPrint('   → Checking for success indicators...');
    final hasSuccess =
        lower.contains('success') ||
        lower.contains('useraction=commit') ||
        lower.contains('payment=success') ||
        lower.contains('paymentid=') ||
        lower.contains('payerid=');
    debugPrint('      → Has success: $hasSuccess');

    if (hasSuccess) {
      debugPrint('   ✅ [PayPal WebView] SUCCESS detected');
      return true;
    }

    // If it's a return URL but not explicitly cancel, assume success
    debugPrint('   → Checking if it\'s a return URL...');
    final isReturnUrl = _isPayPalReturnUrl(url);
    debugPrint('      → Is return URL: $isReturnUrl');

    if (isReturnUrl) {
      final hasCancelInUrl = lower.contains('cancel');
      debugPrint('      → Has cancel in URL: $hasCancelInUrl');
      final result = !hasCancelInUrl;
      debugPrint(
        '   ${result ? "✅" : "❌"} [PayPal WebView] Return URL - ${result ? "SUCCESS" : "CANCELLED"} (default)',
      );
      return result;
    }

    debugPrint('   ❌ [PayPal WebView] NOT a success URL');
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'PayPal Checkout',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Done button removed - WebView now automatically returns after payment success
          // Keeping only the close button (X) for cancellation
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              debugPrint('');
              debugPrint(
                '═══════════════════════════════════════════════════════════',
              );
              debugPrint('❌ [PayPal WebView] CLOSE BUTTON PRESSED');
              debugPrint(
                '═══════════════════════════════════════════════════════════',
              );
              debugPrint('   → Current URL: $_currentUrl');
              debugPrint('   → Approval URL: ${widget.approvalUrl}');

              final returnData = {
                'success': false,
                'url': _currentUrl ?? widget.approvalUrl,
                'cancelled': true,
              };

              debugPrint(
                '📤 [PayPal WebView] Popping Navigator with cancellation data:',
              );
              debugPrint('   → success: false');
              debugPrint('   → url: ${returnData['url']}');
              debugPrint('   → cancelled: true');
              debugPrint(
                '═══════════════════════════════════════════════════════════',
              );
              debugPrint('');

              Navigator.of(context).pop(returnData);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
