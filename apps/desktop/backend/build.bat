@echo off

echo ===============================
echo Killing running EXE...
echo ===============================
taskkill /F /IM HotDropBLE.exe 2>nul

echo ===============================
echo Cleaning old builds...
echo ===============================
rmdir /s /q build 2>nul
rmdir /s /q dist 2>nul
del HotDropBLE.spec 2>nul

echo ===============================
echo Building Python EXE...
echo ===============================
cd C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\backend

pyinstaller --onefile --noconsole ^
--name HotDropBLE ^
--hidden-import bleak.backends.winrt ^
--hidden-import winrt.windows.devices.bluetooth ^
--hidden-import winrt.windows.devices.bluetooth.genericattributeprofile ^
--hidden-import winrt.windows.storage.streams ^
--collect-all llama_cpp ^
--add-data "C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\backend\venv\Lib\site-packages\llama_cpp\lib;llama_cpp/lib" ^
main.py

echo ===============================
echo Copying EXE to Flutter assets...
echo ===============================
del C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\assets\bin\HotDropBLE.exe 2>nul
copy dist\HotDropBLE.exe C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\assets\bin\HotDropBLE.exe

echo ===============================
echo Running Flutter app...
echo ===============================
cd C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\

call flutter clean

cd C:\Users\olildu\Documents\Code\Personal\HotDrop\apps\desktop\backend

echo ===============================
echo DONE
echo ===============================
pause