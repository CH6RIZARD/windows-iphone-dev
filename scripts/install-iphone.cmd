@echo off
rem Build, sign and install an app from ~/apps/<Name> in Ubuntu onto the plugged-in iPhone.
rem Usage: install-iphone.cmd [Name]   (default: Hello). Uses the saved xtool sign-in; no password needed.
set APP=%~1
if "%APP%"=="" set APP=Hello
wsl -d Ubuntu -- bash -lic "cd ~/apps/%APP% && xtool dev"
pause
