// @dart = 2.9

// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pedantic/pedantic.dart';

import './test_utils.dart';

void runInstanceTests() {
  group('FirebaseAuth.instance', () {
    Future<void> commonSuccessCallback(currentUserCredential) async {
      var currentUser = currentUserCredential.user;

      expect(currentUser, isInstanceOf<Object>());
      expect(currentUser.uid, isInstanceOf<String>());
      expect(currentUser.email, equals(testEmail));
      expect(currentUser.isAnonymous, isFalse);
      expect(currentUser.uid, equals(FirebaseAuth.instance.currentUser.uid));

      var additionalUserInfo = currentUserCredential.additionalUserInfo;
      expect(additionalUserInfo, isInstanceOf<Object>());
      expect(additionalUserInfo.isNewUser, isFalse);

      await FirebaseAuth.instance.signOut();
    }

    group('authStateChanges()', () {
      StreamSubscription subscription;
      StreamSubscription subscription2;

      tearDown(() async {
        await subscription?.cancel();
        await ensureSignedOut();

        if (subscription2 != null) {
          await Future.delayed(const Duration(seconds: 5));
          await subscription2.cancel();
        }
      });

      test('calls callback with the current user and when auth state changes',
          () async {
        await ensureSignedIn(testEmail);
        String uid = FirebaseAuth.instance.currentUser.uid;

        Stream<User> stream = FirebaseAuth.instance.authStateChanges();
        int call = 0;

        subscription = stream.listen(expectAsync1((User user) {
          call++;
          if (call == 1) {
            expect(user.uid, isA<String>());
            expect(user.uid, equals(uid)); // initial user
          } else if (call == 2) {
            expect(user, isNull); // logged out
          } else if (call == 3) {
            expect(user.uid, isA<String>());
            expect(user.uid != uid, isTrue); // anonymous user
          } else {
            fail('Should not have been called');
          }
        }, count: 3, reason: 'Stream should only have been called 3 times'));

        // Prevent race condition where signOut is called before the stream hits
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInAnonymously();
      });
    });

    group('idTokenChanges()', () {
      StreamSubscription subscription;
      StreamSubscription subscription2;

      tearDown(() async {
        await subscription?.cancel();
        await ensureSignedOut();

        if (subscription2 != null) {
          await Future.delayed(const Duration(seconds: 5));
          await subscription2.cancel();
        }
      });

      test('calls callback with the current user and when auth state changes',
          () async {
        await ensureSignedIn(testEmail);
        String uid = FirebaseAuth.instance.currentUser.uid;

        Stream<User> stream = FirebaseAuth.instance.idTokenChanges();
        int call = 0;

        subscription = stream.listen(expectAsync1((User user) {
          call++;
          if (call == 1) {
            expect(user.uid, equals(uid)); // initial user
          } else if (call == 2) {
            expect(user, isNull); // logged out
          } else if (call == 3) {
            expect(user.uid, isA<String>());
            expect(user.uid != uid, isTrue); // anonymous user
          } else {
            fail('Should not have been called');
          }
        }, count: 3, reason: 'Stream should only have been called 3 times'));

        // Prevent race condition where signOut is called before the stream hits
        await FirebaseAuth.instance.signOut();
        await FirebaseAuth.instance.signInAnonymously();
      });
    });

    group('userChanges()', () {
      StreamSubscription subscription;
      tearDown(() async {
        await subscription.cancel();
      });

      test('fires once on first initialization of FirebaseAuth', () async {
        // Fixes a very specific bug: https://github.com/FirebaseExtended/flutterfire/issues/3628
        // If the first initialization of FirebaseAuth involves the listeners userChanges() or idTokenChanges()
        // the user will receive two events. Why? The native SDK listener will always fire an event upon initial
        // listen. FirebaseAuth also sends an initial synthetic event. We send a synthetic event because, ordinarily, the user will
        // not use a listener as the first occurrence of FirebaseAuth. We, therefore, mimic native behaviour by sending an
        // event. This test proves the logic of PR: https://github.com/FirebaseExtended/flutterfire/pull/6560

        // Requires a fresh app.
        FirebaseApp second = await Firebase.initializeApp(
            name: 'test-init',
            options: const FirebaseOptions(
              apiKey: 'AIzaSyAHAsf51D0A407EklG1bs-5wA7EbyfNFg0',
              appId: '1:448618578101:ios:4cd06f56e36384acac3efc',
              messagingSenderId: '448618578101',
              projectId: 'react-native-firebase-testing',
              authDomain: 'react-native-firebase-testing.firebaseapp.com',
              iosClientId:
                  '448618578101-m53gtqfnqipj12pts10590l37npccd2r.apps.googleusercontent.com',
            ));

        Stream<User> stream =
            FirebaseAuth.instanceFor(app: second).userChanges();

        subscription = stream.listen(
          expectAsync1(
            (User user) {},
            count: 1,
            reason: 'Stream should only call once',
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
      });

      test('calls callback with the current user and when user state changes',
          () async {
        await ensureSignedIn(testEmail);

        Stream<User> stream = FirebaseAuth.instance.userChanges();
        int call = 0;

        subscription = stream.listen(expectAsync1((User user) {
          call++;
          if (call == 1) {
            expect(user.displayName, isNull); // initial user
          } else if (call == 2) {
            expect(user.displayName, equals('updatedName')); // updated profile
          } else {
            fail('Should not have been called');
          }
        }, count: 2, reason: 'Stream should only have been called 2 times'));

        await FirebaseAuth.instance.currentUser
            .updateDisplayName('updatedName');

        await FirebaseAuth.instance.currentUser.reload();

        expect(
          FirebaseAuth.instance.currentUser.displayName,
          equals('updatedName'),
        );
      });
    });

    group('currentUser', () {
      test('should return currentUser', () async {
        await ensureSignedIn(testEmail);
        var currentUser = FirebaseAuth.instance.currentUser;
        expect(currentUser, isA<User>());
      });
    });

    group('applyActionCode', () {
      test('throws if invalid code', () async {
        try {
          await FirebaseAuth.instance.applyActionCode('!!!!!!');
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('invalid-action-code'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('checkActionCode()', () {
      test('throws on invalid code', () async {
        try {
          await FirebaseAuth.instance.checkActionCode('!!!!!!');
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('invalid-action-code'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('confirmPasswordReset()', () {
      test('throws on invalid code', () async {
        try {
          await FirebaseAuth.instance
              .confirmPasswordReset(code: '!!!!!!', newPassword: 'thingamajig');
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('invalid-action-code'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('createUserWithEmailAndPassword', () {
      test('should create a user with an email and password', () async {
        var email = generateRandomEmail();

        Function successCallback = (UserCredential newUserCredential) async {
          expect(newUserCredential.user, isA<User>());
          User newUser = newUserCredential.user;

          expect(newUser.uid, isA<String>());
          expect(newUser.email, equals(email));
          expect(newUser.emailVerified, isFalse);
          expect(newUser.isAnonymous, isFalse);
          expect(newUser.uid, equals(FirebaseAuth.instance.currentUser.uid));

          var additionalUserInfo = newUserCredential.additionalUserInfo;
          expect(additionalUserInfo, isA<AdditionalUserInfo>());
          expect(additionalUserInfo.isNewUser, isTrue);

          await FirebaseAuth.instance.currentUser?.delete();
        };

        await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
                email: email, password: testPassword)
            .then(successCallback);
      });

      test('fails if creating a user which already exists', () async {
        await ensureSignedIn(testEmail);
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: testEmail, password: '123456');
          fail('Should have thrown FirebaseAuthException');
        } on FirebaseAuthException catch (e) {
          expect(e.code, equals('email-already-in-use'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('fails if creating a user with an invalid email', () async {
        await ensureSignedIn(testEmail);
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: '!!!!!', password: '123456');
          fail('Should have thrown FirebaseAuthException');
        } on FirebaseAuthException catch (e) {
          expect(e.code, equals('invalid-email'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('fails if creating a user if providing a weak password', () async {
        await ensureSignedIn(testEmail);
        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: generateRandomEmail(), password: '1');
          fail('Should have thrown FirebaseAuthException');
        } on FirebaseAuthException catch (e) {
          expect(e.code, equals('weak-password'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('fetchSignInMethodsForEmail()', () {
      test('should return password provider for an email address', () async {
        var providers =
            await FirebaseAuth.instance.fetchSignInMethodsForEmail(testEmail);
        expect(providers, isList);
        expect(providers.contains('password'), isTrue);
      });

      test('should return empty array for a not found email', () async {
        var providers = await FirebaseAuth.instance
            .fetchSignInMethodsForEmail(generateRandomEmail());

        expect(providers, isList);
        expect(providers, isEmpty);
      });

      test('throws for a bad email address', () async {
        try {
          await FirebaseAuth.instance.fetchSignInMethodsForEmail('foobar');
          fail('Should have thrown');
        } on FirebaseAuthException catch (e) {
          expect(e.code, equals('invalid-email'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('isSignInWithEmailLink()', () {
      test('should return true or false', () {
        const emailLink1 =
            'https://www.example.com/action?mode=signIn&oobCode=oobCode';
        const emailLink2 =
            'https://www.example.com/action?mode=verifyEmail&oobCode=oobCode';
        const emailLink3 = 'https://www.example.com/action?mode=signIn';
        const emailLink4 =
            'https://x59dg.app.goo.gl/?link=https://rnfirebase-b9ad4.firebaseapp.com/__/auth/action?apiKey%3Dfoo%26mode%3DsignIn%26oobCode%3Dbar';

        expect(FirebaseAuth.instance.isSignInWithEmailLink(emailLink1),
            equals(true));
        expect(FirebaseAuth.instance.isSignInWithEmailLink(emailLink2),
            equals(false));
        expect(FirebaseAuth.instance.isSignInWithEmailLink(emailLink3),
            equals(false));
        expect(FirebaseAuth.instance.isSignInWithEmailLink(emailLink4),
            equals(true));
      });
    });

    group('sendPasswordResetEmail()', () {
      test('should not error', () async {
        var email = generateRandomEmail();

        try {
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: email, password: testPassword);

          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
          await FirebaseAuth.instance.currentUser.delete();
        } catch (e) {
          await FirebaseAuth.instance.currentUser.delete();
          fail(e.toString());
        }
      });

      test('fails if the user could not be found', () async {
        try {
          await FirebaseAuth.instance
              .sendPasswordResetEmail(email: 'does-not-exist@bar.com');
          fail('Should have thrown');
        } on FirebaseAuthException catch (e) {
          expect(e.code, equals('user-not-found'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('sendSignInLinkToEmail()', () {
      test('should send email successfully', () async {
        const email = 'email-signin-test@example.com';
        const continueUrl = 'http://action-code-test.com';

        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: testPassword,
        );

        final actionCodeSettings = ActionCodeSettings(
          url: continueUrl,
          handleCodeInApp: true,
        );

        await FirebaseAuth.instance.sendSignInLinkToEmail(
          email: email,
          actionCodeSettings: actionCodeSettings,
        );

        // Confirm with the emulator that it triggered an email sending code.
        final oobCode =
            await emulatorOutOfBandCode(email, EmulatorOobCodeType.emailSignIn);
        expect(oobCode, isNotNull);
        expect(oobCode.email, email);
        expect(oobCode.type, EmulatorOobCodeType.emailSignIn);

        // Confirm the continue url was passed through to backend correctly.
        final url = Uri.parse(oobCode.oobLink);
        expect(url.queryParameters['continueUrl'], Uri.encodeFull(continueUrl));
      });
    });

    group('languageCode', () {
      test('should change the language code', () async {
        await FirebaseAuth.instance.setLanguageCode('en');

        expect(FirebaseAuth.instance.languageCode, equals('en'));
      });

      test('should allow null value and default the device language code',
          () async {
        await FirebaseAuth.instance.setLanguageCode(null);

        expect(FirebaseAuth.instance.languageCode,
            isNotNull); // default to the device language or the Firebase projects default language
      }, skip: kIsWeb);

      test('should allow null value and set to null', () async {
        await FirebaseAuth.instance.setLanguageCode(null);

        expect(FirebaseAuth.instance.languageCode, null);
      }, skip: !kIsWeb);
    });

    group('setPersistence()', () {
      test('throw an unimplemented error', () async {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
          fail('Should have thrown');
        } catch (e) {
          expect(e, isInstanceOf<UnimplementedError>());
        }
      }, skip: kIsWeb);

      test('should set persistence', () async {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (e) {
          fail('unexpected error thrown');
        }
      }, skip: !kIsWeb);
    });

    group('signInAnonymously()', () {
      test('should sign in anonymously', () async {
        Function successCallback =
            (UserCredential currentUserCredential) async {
          var currentUser = currentUserCredential.user;

          expect(currentUser, isA<User>());
          expect(currentUser.uid, isA<String>());
          expect(currentUser.email, isNull);
          expect(currentUser.isAnonymous, isTrue);
          expect(
              currentUser.uid, equals(FirebaseAuth.instance.currentUser.uid));

          var additionalUserInfo = currentUserCredential.additionalUserInfo;
          expect(additionalUserInfo, isInstanceOf<Object>());

          await FirebaseAuth.instance.signOut();
        };

        await FirebaseAuth.instance.signInAnonymously().then(successCallback);
      });
    });

    group('signInWithCredential()', () {
      test('should login with email and password', () async {
        var credential = EmailAuthProvider.credential(
            email: testEmail, password: testPassword);
        await FirebaseAuth.instance
            .signInWithCredential(credential)
            .then(commonSuccessCallback);
      });

      test('throws if login user is disabled', () async {
        var credential = EmailAuthProvider.credential(
          email: testDisabledEmail,
          password: testPassword,
        );

        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('user-disabled'));
          expect(
              e.message,
              equals(
                  'The user account has been disabled by an administrator.'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('throws if login password is incorrect', () async {
        var credential =
            EmailAuthProvider.credential(email: testEmail, password: 'sowrong');
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('wrong-password'));
          expect(
              e.message,
              equals(
                  'The password is invalid or the user does not have a password.'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('throws if login user is not found', () async {
        var credential = EmailAuthProvider.credential(
            email: generateRandomEmail(), password: testPassword);
        try {
          await FirebaseAuth.instance.signInWithCredential(credential);
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('user-not-found'));
          expect(
              e.message,
              equals(
                  'There is no user record corresponding to this identifier. The user may have been deleted.'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('signInWithCustomToken()', () {
      test('signs in with custom auth token', () async {
        final userCredential = await FirebaseAuth.instance.signInAnonymously();
        final uid = userCredential.user.uid;
        final claims = {
          'roles': [
            {'role': 'member'},
            {'role': 'admin'}
          ]
        };

        await ensureSignedOut();

        expect(FirebaseAuth.instance.currentUser, null);

        final customToken = emulatorCreateCustomToken(uid, claims: claims);

        final customTokenUserCredential =
            await FirebaseAuth.instance.signInWithCustomToken(customToken);

        expect(customTokenUserCredential.user.uid, equals(uid));
        expect(FirebaseAuth.instance.currentUser.uid, equals(uid));

        final idTokenResult =
            await FirebaseAuth.instance.currentUser.getIdTokenResult();

        expect(idTokenResult.claims['roles'], isA<List>());
        expect(idTokenResult.claims['roles'][0], isA<Map>());
        expect(idTokenResult.claims['roles'][0]['role'], 'member');
      });
    });

    group('signInWithEmailAndPassword()', () {
      test('should login with email and password', () async {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: testEmail, password: testPassword)
            .then(commonSuccessCallback);
      });

      test('throws if login user is disabled', () async {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: testDisabledEmail,
            password: testPassword,
          );
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('user-disabled'));
          expect(
              e.message,
              equals(
                  'The user account has been disabled by an administrator.'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('throws if login password is incorrect', () async {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: testEmail, password: 'sowrong');
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('wrong-password'));
          expect(
              e.message,
              equals(
                  'The password is invalid or the user does not have a password.'));
        } catch (e) {
          fail(e.toString());
        }
      });

      test('throws if login user is not found', () async {
        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
              email: generateRandomEmail(), password: testPassword);
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('user-not-found'));
          expect(
              e.message,
              equals(
                  'There is no user record corresponding to this identifier. The user may have been deleted.'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('signOut()', () {
      test('should sign out', () async {
        await ensureSignedIn(testEmail);
        expect(FirebaseAuth.instance.currentUser, isA<User>());
        await FirebaseAuth.instance.signOut();
        expect(FirebaseAuth.instance.currentUser, isNull);
      });
    });

    group('verifyPasswordResetCode()', () {
      test('throws on invalid code', () async {
        try {
          await FirebaseAuth.instance.verifyPasswordResetCode('!!!!!!');
          fail('Should have thrown');
        } on FirebaseException catch (e) {
          expect(e.code, equals('invalid-action-code'));
        } catch (e) {
          fail(e.toString());
        }
      });
    });

    group('verifyPhoneNumber()', () {
      test('should fail with an invalid phone number', () async {
        Future<Exception> getError() async {
          Completer completer = Completer<FirebaseAuthException>();

          unawaited(FirebaseAuth.instance.verifyPhoneNumber(
              phoneNumber: 'foo',
              verificationCompleted: (PhoneAuthCredential credential) {
                return completer
                    .completeError(Exception('Should not have been called'));
              },
              verificationFailed: (FirebaseAuthException e) {
                completer.complete(e);
              },
              codeSent: (String verificationId, int resetToken) {
                return completer
                    .completeError(Exception('Should not have been called'));
              },
              codeAutoRetrievalTimeout: (String foo) {
                return completer
                    .completeError(Exception('Should not have been called'));
              }));

          return completer.future;
        }

        Exception e = await getError();
        expect(e, isA<FirebaseAuthException>());
        FirebaseAuthException exception = e as FirebaseAuthException;
        expect(exception.code, equals('invalid-phone-number'));
      });

      test('should auto verify phone number', () async {
        String testPhoneNumber = '+447444555666';
        String testSmsCode = '123456';
        await FirebaseAuth.instance.signInAnonymously();

        Future<PhoneAuthCredential> getCredential() async {
          Completer completer = Completer<PhoneAuthCredential>();

          unawaited(FirebaseAuth.instance.verifyPhoneNumber(
              phoneNumber: testPhoneNumber,
              // ignore: invalid_use_of_visible_for_testing_member
              autoRetrievedSmsCodeForTesting: testSmsCode,
              verificationCompleted: (PhoneAuthCredential credential) {
                if (credential.smsCode != testSmsCode) {
                  return completer
                      .completeError(Exception('SMS code did not match'));
                }

                completer.complete(credential);
              },
              verificationFailed: (FirebaseException e) {
                return completer
                    .completeError(Exception('Should not have been called'));
              },
              codeSent: (String verificationId, int resetToken) {
                return completer
                    .completeError(Exception('Should not have been called'));
              },
              codeAutoRetrievalTimeout: (String foo) {
                return completer
                    .completeError(Exception('Should not have been called'));
              }));

          return completer.future;
        }

        PhoneAuthCredential credential = await getCredential();
        expect(credential, isA<PhoneAuthCredential>());
      }, skip: kIsWeb || defaultTargetPlatform != TargetPlatform.android);
    }, skip: defaultTargetPlatform == TargetPlatform.macOS || kIsWeb);

    group('setSettings()', () {
      test(
          'throws argument error if phoneNumber & smsCode have not been set simultaneously',
          () async {
        String message =
            "The [smsCode] and the [phoneNumber] must both be either 'null' or a 'String''.";
        await expectLater(
            FirebaseAuth.instance.setSettings(phoneNumber: '123456'),
            throwsA(isA<ArgumentError>()
                .having((e) => e.message, 'message', contains(message))));

        await expectLater(
            FirebaseAuth.instance.setSettings(smsCode: '123456'),
            throwsA(isA<ArgumentError>()
                .having((e) => e.message, 'message', contains(message))));
      }, skip: kIsWeb || defaultTargetPlatform != TargetPlatform.android);
    });

    group('tenantId', () {
      test('User associated with the tenantId correctly', () async {
        // tenantId created in the GCP console
        const String tenantId = 'auth-tenant-test-xukxg';
        // created User on GCP console associated with the above tenantId
        final userCredential = await FirebaseAuth.instance
            .signInWithEmailAndPassword(
                email: 'test-tenant@email.com', password: 'fake-password');

        expect(userCredential.user.tenantId, tenantId);
      });
      // todo(russellwheatley85): get/set tenantId and authenticating user via auth emulator is not possible at the moment.
    }, skip: true);
  });
}
