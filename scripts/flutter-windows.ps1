# Installs Flutter 3.47.6 for Windows at E:\flutter (Android builds). Log: E:\flutter-windows.log
Start-Transcript E:\flutter-windows.log -Append
$ErrorActionPreference = 'Stop'
$zip = 'E:\flutter_windows_3.47.6-stable.zip'
if (-not (Test-Path E:\flutter\bin\flutter.bat)) {
  curl.exe -fL --retry 5 -C - -o $zip https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.47.6-stable.zip
  tar.exe -xf $zip -C E:\    # bsdtar is much faster than Expand-Archive
  Remove-Item $zip
}
$userPath = [Environment]::GetEnvironmentVariable('Path','User')
if ($userPath -notlike '*E:\flutter\bin*') { [Environment]::SetEnvironmentVariable('Path', "$userPath;E:\flutter\bin", 'User') }
$env:Path += ';E:\flutter\bin'
git config --global --add safe.directory '*'
flutter config --no-analytics
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter doctor -v
'== ALL DONE'
Stop-Transcript
