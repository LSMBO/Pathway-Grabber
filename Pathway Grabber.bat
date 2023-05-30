@echo off

set PATH=%PATH%;%cd%\git\bin;%cd%\node-v20.2.0-win-x64
set JULIA_DEPOT_PATH=%cd%\Julia-1.8.5\depot

npm run start

pause