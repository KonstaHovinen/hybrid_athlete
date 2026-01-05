@echo off
REM This batch file will launch your Flutter app as a Windows desktop application
cd /d %~dp0
flutter run -d windows
pause