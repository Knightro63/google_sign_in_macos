# Archived

Since the flutter team has added google_sign_in_macos to their repo this is no longer maintained. Please use [google_sign_in_ios](https://github.com/flutter/packages/tree/main/packages/google_sign_in/google_sign_in_ios).

# google\_sign\_in\_macos

The osx implementation of [`google_sign_in`][1].

### Mac integration

1. [First register your application](https://firebase.google.com/docs/ios/setup).
2. Make sure the file you download in step 1 is named
   `GoogleService-Info.plist`.
3. Move or copy `GoogleService-Info.plist` into the `[my_project]/macos/Runner`
   directory.
4. Open Xcode, then right-click on `Runner` directory and select
   `Add Files to "Runner"`.
5. Select `GoogleService-Info.plist` from the file manager.
6. A dialog will show up and ask you to select the targets, select the `Runner`
   target.
7. If you need to authenticate to a backend server you can add a 
   `SERVER_CLIENT_ID` key value pair in your `GoogleService-Info.plist`.
   ```xml
   <key>SERVER_CLIENT_ID</key>
   <string>[YOUR SERVER CLIENT ID]</string>
   ```
8. Then add the `CFBundleURLTypes` attributes below into the
   `[my_project]/ios/Runner/Info.plist` file.

```xml
<!-- Put me in the [my_project]/ios/Runner/Info.plist file -->
<!-- Google Sign-in Section -->
<key>CFBundleURLTypes</key>
<array>
	<dict>
		<key>CFBundleTypeRole</key>
		<string>Editor</string>
		<key>CFBundleURLSchemes</key>
		<array>
			<!-- TODO Replace this value: -->
			<!-- Copied from GoogleService-Info.plist key REVERSED_CLIENT_ID -->
			<string>com.googleusercontent.apps.861823949799-vc35cprkp249096uujjn0vvnmcvjppkn</string>
		</array>
	</dict>
</array>
<!-- End of the Google Sign-in Section -->
```

9. Required for Mac. Add the `com.google.GIDSignIn` Keychain sharing into the
   `Signing  & Capabilities -> Keychain Sharing`.

As an alternative to adding `GoogleService-Info.plist` to your Xcode project, 
you can instead configure your app in Dart code. In this case, skip steps 3 to 7
and pass `clientId` and `serverClientId` to the `GoogleSignIn` constructor:

```dart
GoogleSignIn _googleSignIn = GoogleSignIn(
  ...
  // The OAuth client id of your app. This is required.
  clientId: ...,
  // If you need to authenticate to a backend server, specify its OAuth client. This is optional.
  serverClientId: ...,
);
```

Note that step 8 and 9 are still required.
