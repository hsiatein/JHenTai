version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build apk -t lib/src/main.dart --release --split-per-abi
cd build/app/outputs/apk/release
mv app-arm64-v8a-release.apk JHenTai-8.0.6+278-arm64-v8a.apk
mv app-armeabi-v7a-release.apk JHenTai-8.0.6+278-armeabi-v7a.apk
mv app-x86_64-release.apk JHenTai-8.0.6+278-x64.apk