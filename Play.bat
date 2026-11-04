@echo off
rem Launches Golferino with the installed Godot editor binary.
set "GODOT=E:\GoDOT\Godot_v4.6.2-stable_win64.exe"
if not exist "%GODOT%" (
  echo Could not find Godot at %GODOT%
  pause
  exit /b 1
)
"%GODOT%" --path "%~dp0." %*
if errorlevel 1 (
  echo Godot exited with an error. See the message above.
  pause
)
