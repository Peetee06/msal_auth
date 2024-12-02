import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:msal_auth/msal_auth.dart';

import 'data/test_data.dart';
import 'utils/method_call_matcher.dart';
import 'utils/widget_tester_extensions.dart';

void main() {
  const mockAndroidConfigPath = 'some_path/android_config.json';

  tearDown(rootBundle.clear);

  Future<SingleAccountPca> setupAndCreateAndroidPca(WidgetTester tester) async {
    tester.mockRootBundleLoadString(
      mockAndroidConfigPath,
      androidConfigString,
    );
    return SingleAccountPca.create(
      clientId: 'test',
      androidConfig: AndroidConfig(
        configFilePath: mockAndroidConfigPath,
        redirectUri: 'testRedirectUri',
      ),
    );
  }

  group('SingleAccountPca', () {
    group('create', () {
      testWidgets(
        'throws AssertionError if androidConfig is null on Android platform',
        variant: TargetPlatformVariant.only(TargetPlatform.android),
        (tester) async {
          expect(
            () => SingleAccountPca.create(clientId: 'test'),
            throwsA(
              isA<AssertionError>().having(
                (e) => e.message,
                'message',
                'Android config can not be null',
              ),
            ),
          );
        },
      );

      testWidgets(
        'throws AssertionError if iosConfig is null on iOS platform',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          expect(
            () => SingleAccountPca.create(clientId: 'test'),
            throwsA(
              isA<AssertionError>().having(
                (e) => e.message,
                'message',
                'iOS config can not be null',
              ),
            ),
          );
        },
      );

      testWidgets(
        'invokes createSingleAccountPca with correct arguments for iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          MethodCall? methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            return null;
          });
          final pca = await SingleAccountPca.create(
            clientId: 'testId',
            iosConfig: IosConfig(
              authority: 'testAuthority',
            ),
          );

          expect(pca, isA<SingleAccountPca>());
          expect(
            methodCall,
            equalsMethodCall(
              MethodCall(
                'createSingleAccountPca',
                <String, dynamic>{
                  'clientId': 'testId',
                  'authority': 'testAuthority',
                  'broker': 'msAuthenticator',
                  'authorityType': 'aad',
                },
              ),
            ),
          );
        },
      );

      testWidgets(
        'invokes createSingleAccountPca with correct arguments for Android',
        (tester) async {
          tester.mockRootBundleLoadString(
            mockAndroidConfigPath,
            androidConfigString,
          );
          final androidConfig =
              jsonDecode(androidConfigString) as Map<String, dynamic>;
          MethodCall? methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            return null;
          });

          final pca = await SingleAccountPca.create(
            clientId: 'testId',
            androidConfig: AndroidConfig(
              configFilePath: mockAndroidConfigPath,
              redirectUri: 'testRedirectUri',
            ),
          );
          final expectedConfig = androidConfig
            ..addAll({
              'client_id': 'testId',
              'redirect_uri': 'testRedirectUri',
            });

          expect(pca, isA<SingleAccountPca>());
          expect(
            methodCall,
            equalsMethodCall(
              MethodCall(
                'createSingleAccountPca',
                <String, dynamic>{
                  'config': expectedConfig,
                },
              ),
            ),
          );
        },
      );

      testWidgets(
        'converts PlatformException to MsalException exception '
        'and throws it for iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          tester.setMockMethodCallHandler((call) async {
            throw PlatformException(
              code: 'test',
              message: 'test',
            );
          });
          expect(
            () => SingleAccountPca.create(
              clientId: 'test',
              iosConfig: IosConfig(),
            ),
            throwsA(
              isA<MsalException>().having(
                (e) => e.message,
                'message',
                'test',
              ),
            ),
          );
        },
      );

      testWidgets(
        'converts PlatformException to MsalException exception '
        'and throws it for Android',
        (tester) async {
          tester
            ..mockRootBundleLoadString(
              mockAndroidConfigPath,
              androidConfigString,
            )
            ..setMockMethodCallHandler((call) async {
              throw PlatformException(code: 'test', message: 'test');
            });
          expect(
            () => SingleAccountPca.create(
              clientId: 'test',
              androidConfig: AndroidConfig(
                configFilePath: mockAndroidConfigPath,
                redirectUri: 'testRedirectUri',
              ),
            ),
            throwsA(isA<MsalException>()),
          );
        },
      );
    });

    group('currentAccount', () {
      testWidgets(
        'calls currentAccount and returns Account on iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          MethodCall? methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            return <String, dynamic>{
              'id': 'testId',
              'username': 'testUsername',
              'name': 'testName',
            };
          });
          final pca = await SingleAccountPca.create(
            clientId: 'test',
            iosConfig: IosConfig(),
          );
          final account = await pca.currentAccount;

          expect(
            methodCall,
            equalsMethodCall(
              MethodCall('currentAccount'),
            ),
          );

          expect(account.id, 'testId');
          expect(account.username, 'testUsername');
          expect(account.name, 'testName');
        },
      );

      testWidgets(
        'calls currentAccount and returns Account on Android',
        (tester) async {
          MethodCall? methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            if (call.method == 'currentAccount') {
              return <String, dynamic>{
                'id': 'testId',
                'username': 'testUsername',
                'name': 'testName',
              };
            }
            return null;
          });

          final pca = await setupAndCreateAndroidPca(tester);
          final account = await pca.currentAccount;

          expect(
            methodCall,
            equalsMethodCall(
              MethodCall('currentAccount'),
            ),
          );

          expect(account.id, 'testId');
          expect(account.username, 'testUsername');
          expect(account.name, 'testName');
        },
      );

      testWidgets(
        'converts PlatformException to MsalException exception '
        'and throws it on iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          tester.setMockMethodCallHandler((call) async {
            if (call.method == 'currentAccount') {
              throw PlatformException(code: 'test', message: 'test');
            }
            return null;
          });
          final pca = await SingleAccountPca.create(
            clientId: 'test',
            iosConfig: IosConfig(),
          );

          expect(
            pca.currentAccount,
            throwsA(
              isA<MsalException>().having(
                (e) => e.message,
                'message',
                'test',
              ),
            ),
          );
        },
      );

      testWidgets(
        'converts PlatformException to MsalException exception '
        'and throws it on Android',
        (tester) async {
          tester.setMockMethodCallHandler((call) async {
            if (call.method == 'currentAccount') {
              throw PlatformException(code: 'test', message: 'test');
            }
            return null;
          });

          final pca = await setupAndCreateAndroidPca(tester);

          expect(
            pca.currentAccount,
            throwsA(
              isA<MsalException>().having(
                (e) => e.message,
                'message',
                'test',
              ),
            ),
          );
        },
      );
    });

    group('signOut', () {
      final signOutResult = ValueVariant<bool>({true, false});
      testWidgets(
        'returns native signOut result on iOS',
        variant: signOutResult,
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          late MethodCall methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            return signOutResult.currentValue!;
          });

          final pca = await SingleAccountPca.create(
            clientId: 'test',
            iosConfig: IosConfig(),
          );
          final result = await pca.signOut();

          expect(
            methodCall,
            equalsMethodCall(MethodCall('signOut')),
          );
          expect(result, signOutResult.currentValue!);
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'converts PlatformException to MsalException and throws it on iOS',
        variant: TargetPlatformVariant.only(TargetPlatform.iOS),
        (tester) async {
          tester.setMockMethodCallHandler((call) async {
            if (call.method == 'signOut') {
              throw PlatformException(code: 'test', message: 'test');
            }
            return null;
          });

          final pca = await SingleAccountPca.create(
            clientId: 'test',
            iosConfig: IosConfig(),
          );

          expect(
            pca.signOut,
            throwsA(
              isA<MsalException>().having(
                (e) => e.message,
                'message',
                'test',
              ),
            ),
          );
        },
      );

      testWidgets(
        'returns native signOut result on Android',
        variant: signOutResult,
        (tester) async {
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          late MethodCall methodCall;
          tester.setMockMethodCallHandler((call) async {
            methodCall = call;
            if (call.method == 'signOut') return signOutResult.currentValue!;
            return null;
          });

          final pca = await setupAndCreateAndroidPca(tester);
          final result = await pca.signOut();

          expect(
            methodCall,
            equalsMethodCall(
              MethodCall('signOut'),
            ),
          );
          expect(result, signOutResult.currentValue!);
          debugDefaultTargetPlatformOverride = null;
        },
      );

      testWidgets(
        'converts PlatformException to MsalException and throws it on Android',
        (tester) async {
          tester.setMockMethodCallHandler((call) async {
            if (call.method == 'signOut') {
              throw PlatformException(code: 'test', message: 'test');
            }
            return null;
          });
          final pca = await setupAndCreateAndroidPca(tester);

          expect(
            pca.signOut,
            throwsA(
              isA<MsalException>().having(
                (e) => e.message,
                'message',
                'test',
              ),
            ),
          );
        },
      );
    });
  });
}