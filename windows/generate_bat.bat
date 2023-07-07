@echo off

set "CURRENT_DIRECTORY=%~dp0"
if NOT "%CURRENT_DIRECTORY:~-32%" == "\meowcoin-stratum-proxy\windows\" (
    if NOT "%CURRENT_DIRECTORY:~-37%" == "\meowcoin-stratum-proxy-main\windows\" (
        echo Error: Please run this batch file as-is from its original location in the meowcoin-stratum-proxy folder
	pause
        exit /B
    )
)

echo checking for python...

if exist "%CURRENT_DIRECTORY%python_files\python.exe" (

    echo python.exe exists... assuming all dependancies are installed....
    goto SKIP_DOWNLOADS
)

echo downloading python...
powershell -Command "Invoke-WebRequest https://www.python.org/ftp/python/3.9.13/python-3.9.13-embed-win32.zip -OutFile '%CURRENT_DIRECTORY%python.zip'"

FOR /F "tokens=* USEBACKQ" %%F IN (`powershell -Command "Get-FileHash '%CURRENT_DIRECTORY%python.zip' -Algorithm SHA256 | Select-Object -ExpandProperty Hash"`) DO (
    set HASH=%%F
)
echo downloaded python hash: %HASH%
if NOT "%HASH%" == "F8ED5E019D7BC6DBA1D7DFA5D59052B5241C37E8EAA5293133C898AC7ACEDB98" (
    echo warning: hash mismatch! exiting and removing the file.
    del "%CURRENT_DIRECTORY%python.zip"
    pause
    exit /B
)
echo downloading pip installer
powershell -Command "Invoke-WebRequest https://bootstrap.pypa.io/get-pip.py -OutFile '%CURRENT_DIRECTORY%get-pip.py'"

if NOT exist "%CURRENT_DIRECTORY%get-pip.py" (
    echo failed to download pip installer.
    del "%CURRENT_DIRECTORY%python.zip"
    pause
    exit /B
)

echo extracting python...
powershell -Command "Expand-Archive '%CURRENT_DIRECTORY%python.zip' -DestinationPath '%CURRENT_DIRECTORY%python_files'"

echo installing pip...
"%CURRENT_DIRECTORY%python_files"\python.exe "%CURRENT_DIRECTORY%get-pip.py" --no-warn-script-location

echo removing archives...
del "%CURRENT_DIRECTORY%python.zip"
del "%CURRENT_DIRECTORY%get-pip.py"

echo patching python...
echo Lib\site-packages>> "%CURRENT_DIRECTORY%python_files\python39._pth"

echo installing pre-built module...
"%CURRENT_DIRECTORY%python_files"\python.exe -m pip install "%CURRENT_DIRECTORY%python_modules\pysha3-1.0.3.dev1-cp39-cp39-win32.whl"

echo install pip modules...
"%CURRENT_DIRECTORY%python_files"\python.exe -m pip install -r "%CURRENT_DIRECTORY%requirements.txt" --no-warn-script-location

:SKIP_DOWNLOADS

set "FILE_LOCATION=%CURRENT_DIRECTORY%..\run.bat"

if exist "%FILE_LOCATION%" goto EXISTS
goto CHECK_MAINNET

:EXISTS
echo ==========================================================
set /p "DO_RESET=run.bat already exists, do you want to overwrite? y/n (Default n): "
IF /I "%DO_RESET%" NEQ "Y" exit /B
IF /I "%DO_RESET%" EQU "" exit /B

echo regenerating run.bat ...


echo ==========================================================

:CHECK_MAINNET
set "IS_MAINNET=y"
set /p "IS_MAINNET_INPUT=Is this for mainnet or testnet? (Default mainnet): "
if "%IS_MAINNET_INPUT%" == "" (
    set "IS_MAINNET_INPUT=mainnet"
)

if "%IS_MAINNET_INPUT%" == "mainnet" (
    set "IS_MAINNET=y"
    set "DEFAULT_PORT=9766"
    goto POST_CHECK_MAINNET
)

if "%IS_MAINNET_INPUT%" == "testnet" (
    set "IS_MAINNET="
    set "DEFAULT_PORT=19766"
    goto POST_CHECK_MAINNET
)

echo Unknown input: %IS_MAINNET_INPUT% options are: (mainnet/testnet)
set "IS_MAINNET_INPUT="
goto CHECK_MAINNET

:POST_CHECK_MAINNET
echo ==========================================================
for /f "tokens=3 delims=: " %%i  in ('netsh interface ip show config name^="Ethernet" ^| findstr "IP Address"') do set LOCALIP=%%i

set /p "PROXY_IP=What is the ip of your proxy? (Default %LOCALIP%): "
if "%PROXY_IP%" == "" (
    set "PROXY_IP=%LOCALIP%"
)

echo ==========================================================
:POST_CHECK_ADDRESS

:PRE_CHECK_PORT

set /p "PROXY_PORT=What port would you like to run the converter on? (default 54325): "
if "%PROXY_PORT%" == "" (
    set "PROXY_PORT=54325"
)

set /a "TEST_PORT=%PROXY_PORT%+0"
if %TEST_PORT% LEQ 1024 (
    echo Not a valid port: %PROXY_PORT%
	set "PROXY_PORT="
    goto PRE_CHECK_PORT
)

echo ==========================================================

set /p "RPC_IP=What is the ip of your node? (Default 127.0.0.1): "
if "%RPC_IP%" == "" (
    set "RPC_IP=127.0.0.1"
)

echo ==========================================================
:POST_CHECK_IP

set /p "RPC_PORT=What is the port of your node? (Default %DEFAULT_PORT%): "
if "%RPC_PORT%" == "" (
    set "RPC_PORT=%DEFAULT_PORT%"
)

set /a "TEST_PORT=%RPC_PORT%+0"
if %TEST_PORT% LEQ 1024 (
    echo Not a valid port: %RPC_PORT%
	set "RPC_PORT="
    goto POST_CHECK_IP
)

echo ==========================================================
:POST_CHECK_PORT

set /p "RPC_USERNAME=What is your RPC username?: "
if "%RPC_USERNAME%" == "" (
    echo You must input a username
    goto POST_CHECK_PORT
)

echo ==========================================================
:POST_CHECK_USERNAME

set /p "RPC_PASSWORD=What is your RPC password?: "
if "%RPC_PASSWORD%" == "" (
    echo You must input a password
    goto POST_CHECK_USERNAME
)

echo ==========================================================
:POST_CHECK_PASSWORD

set "SHOW_JOBS=-j"
set /p "TEST_SHOW_JOBS=Show jobs in the log (Y/[N]): "
IF /I "%TEST_SHOW_JOBS%" NEQ "Y" set "SHOW_JOBS="

echo ==========================================================
:POST_CHECK_JOBS

set "VERBOSE=-v"
set /p "TEST_VERBOSE=Verbose logging (Y/[N]): "
IF /I "%TEST_VERBOSE%" NEQ "Y" set "VERBOSE="

echo ==========================================================
:POST_CHECK_JOBS

set "TESTNET="
if NOT defined IS_MAINNET set "TESTNET=-t"

echo generating bat file...
echo @echo off>"%FILE_LOCATION%"
echo echo ==========================================================>>"%FILE_LOCATION%"
echo echo Connect to your stratum proxy (with a miner) at stratum+tcp://%PROXY_IP%:%PROXY_PORT%>>"%FILE_LOCATION%"
echo echo ==========================================================>>"%FILE_LOCATION%"
echo "%CURRENT_DIRECTORY%python_files\python.exe" "%CURRENT_DIRECTORY%..\meowcoin-stratum-proxy.py" --address %PROXY_IP% --port %PROXY_PORT% --rpcip %RPC_IP% --rpcport %RPC_PORT% --rpcuser %RPC_USERNAME%  --rpcpass %RPC_PASSWORD% %TESTNET% %SHOW_JOBS% %VERBOSE%>>"%FILE_LOCATION%"
FOR %%A IN ("%~dp0.") DO SET FILE_LOCATION=%%~dpA
echo done... runnable bat can be found at %FILE_LOCATION%run.bat
:: Cleanup Variables
set "PROXY_IP="
set "PROXY_PORT="
set "RPC_USERNAME="
set "RPC_PASSWORD="
set "RPC_IP="
set "RPC_PORT="
set "SHOW_JOBS="
set "VERBOSE="
set "TESTNET="
set "IS_MAINNET="
set "IS_MAINNET_INPUT="
set "DEFAULT_PORT="
set "TEST_PORT="
set "TEST_SHOW_JOBS="
set "TEST_VERBOSE="
set "DO_RESET="
pause
