# Shopping List

A personal grocery list for Android. Build a list, shop it in a mode designed
for one hand and a trolley, close it out with the total and a photo of the
receipt, and keep the record.

## Where things are

```
lib/
  design/          tokens, theme, and the signature widgets (burn, tear, perforation)
  data/            models, DAOs, SQLite schema, image storage, repository
  state/           Riverpod providers and controllers
  features/
    list/          the main list — the paper roll
    pickup/        Pick-Up Mode
    checkout/      total + receipt capture
    history/       past trips and their receipts
  util/            money (integer agorot) and name normalisation
test/              runs headless against in-memory SQLite — no device needed
```

## Setup

Flutter and the Android SDK are not yet installed on this machine, and
`ANDROID_HOME` currently points at a directory that doesn't exist.

**1. Flutter** (needs an elevated shell):

```
choco install flutter -y
```

**2. Android SDK.** Open Android Studio → *More Actions* → *SDK Manager*, and
install the Android SDK, platform-tools, and a recent build-tools. This also
creates the directory `ANDROID_HOME` is already pointing at.

**3. Generate the platform folders.** The Dart code and `pubspec.yaml` are
already written; this fills in `android/` around them:

```
flutter create . --project-name shopping_list --org com.amirw --platforms=android
```

Check afterwards that `pubspec.yaml` still lists the dependencies and the three
bundled font families — if `flutter create` rewrote it, restore it from git.

**4. Finish up:**

```
flutter doctor --android-licenses
flutter doctor -v
flutter pub get
```

**5. Android manifest.** On Android 11+ an app must declare the intents it
queries before it can launch the camera. Add to `android/app/src/main/AndroidManifest.xml`,
as a direct child of `<manifest>`:

```xml
<queries>
  <intent>
    <action android:name="android.media.action.IMAGE_CAPTURE" />
  </intent>
</queries>
```

## Running

```
flutter analyze
flutter test            # data layer, headless
flutter run             # with a device attached or an emulator running
```

## Notes on the design

The receipt is the one physical artifact this app actually stores, so it is
where the visual identity comes from rather than being a metaphor applied on
top.

**Money is never a `double`.** Totals are stored, parsed, compared and formatted
as an integer count of agorot. `Money.tryParse` splits on the decimal point and
parses each side as an integer, because `double.parse('142.50') * 100` is
`14249.999999999998`. See `test/money_test.dart`.

**Receipt paths are stored relative to the documents directory.** The absolute
container path changes between installs and OS upgrades, so an absolute path
recorded today silently stops resolving later. `ImageStore` also copies images
out of the picker's cache directory, which the OS is free to purge.

**History is a record, not a live view.** `trip_items.name_snapshot` holds the
name as it was when the item was added, so renaming a product later doesn't
rewrite what a past trip says was bought.

**At most one trip is active**, enforced by a partial unique index in SQLite
rather than trusted to application code — a second insert fails loudly instead
of quietly producing two "current" lists.
