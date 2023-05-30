@echo off

set zp=%cd%\install\7zip\7za.exe

if not exist %cd%\git (
    echo Decompressing git
    %zp% x %cd%\install\git.zip
)

if not exist %cd%\node-v20.2.0-win-x64 (
    echo Decompressing nodeJS
    %zp% x %cd%\install\node-v20.2.0-win-x64.zip
)

if not exist %cd%\Julia-1.8.5 (
    echo Decompressing Julia-1.8.5
    %zp% x %cd%\install\Julia-1.8.5.zip
)

set JULIA_DEPOT_PATH=%cd%\Julia-1.8.5\depot
if not exist %JULIA_DEPOT_PATH% (
    echo Installing Julia packages, it may take a while.
    %cd%\Julia-1.8.5\bin\julia.exe -e "using Pkg; Pkg.add.([\"Base64\", \"Combinatorics\", \"Dates\", \"DelimitedFiles\", \"GZip\", \"HTTP\", \"Images\", \"JSON\", \"OrderedCollections\", \"Test\", \"XLSX\", \"ZipFile\", \"Logging\", \"LoggingExtras\", \"Gzip_jll\", \"FilesystemDatastructures\"])"
)

pause