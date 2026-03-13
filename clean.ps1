flutter clean
Remove-Item -Recurse -Force .dart_tool -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
flutter pub get