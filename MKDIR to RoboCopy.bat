@echo off
setlocal enabledelayedexpansion

:: Get the path to the Desktop
set "desktopPath=%USERPROFILE%\Desktop"

:: Prompt for destination server name
set /p serverName=Enter destination server name (e.g., ServerName): 

:: Check if serverName is provided
if "%serverName%"=="" (
    echo No server name provided. Exiting...
    pause
    exit /b
)

:: Define output file path for robocopy commands on the Desktop
set "outputFile=%desktopPath%\robocopy_commands.bat"

:: Clear the output file (or create it if it doesn't exist)
echo. > "%outputFile%"

:: Inform the user to paste the mkdir commands
echo.
echo Please paste your mkdir commands below.
echo When finished, press CTRL+Z and hit Enter to save.
echo.

:: Read the input and process each line
:readinput
set "input="
set /p input=
if not defined input goto done

echo %input% | findstr /b "mkdir" >nul
if not errorlevel 1 (
    :: Extract the directory path while keeping spaces intact
    for /f "tokens=2,* delims= " %%B in ("%input%") do (
        set "sourceDir=%%B %%C"

        :: Trim trailing spaces and remove extra quotes
        for /f "tokens=* delims= " %%D in ("!sourceDir!") do set "sourceDir=%%D"
        set "sourceDir=!sourceDir:"=!"

        :: Extract drive letter and folder path
        set "driveLetter=!sourceDir:~0,2!"
        set "folderPath=!sourceDir:~3!"

        :: Construct the target directory path
        set "targetDir=\\%serverName%\!driveLetter:~0,1!$\!folderPath!"

        :: Write formatted robocopy command to file
        echo robocopy "!sourceDir!" "!targetDir!" /E /B /COPYALL /MIR /R:1 /W:2 /V /TEE /LOG+:"C:\Temp\!folderPath!log.txt" >> "%outputFile%"
    )
)

goto readinput

:done
echo.
echo Script complete! The robocopy commands have been saved to "%outputFile%".
pause
