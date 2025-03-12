flutter build windows -t lib/src/main.dart --release
$DestDir = "build\windows\JHenTai_8.0.6+278"
$SrcDir = "build\windows\x64\runner\Release"
New-Item -Path $DestDir -ItemType Directory
Copy-Item $SrcDir\* -Recurse $DestDir
Copy-Item -Filter *.dll -Path windows\* -Destination $DestDir -Force
Compress-Archive $DestDir build\windows\JHenTai_8.0.6+278_Windows.zip