flutter precache --ios
cd ios
pod update
cd ..
flutter build ios -t lib/src/main.dart --release --no-codesign
sh thin-payload.sh build/ios/iphoneos/*.app
cd build
mkdir -p Payload
mv ios/iphoneos/*.app Payload
zip -9 JHenTai_8.0.6+278.ipa -r Payload
