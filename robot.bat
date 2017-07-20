@echo off

SETLOCAL
set robotIndent=%robotIndent%

: Launches the script in another cmd process to support using "exit" to exit a subroutine.
: Otherwise, "exit" closes the entire command window.
IF "%selfWrapped%"=="" (
  SET selfWrapped=true
  %ComSpec% /s /c ""%~0" %*"
  GOTO :EOF
)

call :parseArgs %*

: Sets an environment variable that is used by the tests to figure out where "home" is.
set ROBOT_HOME_DIR=%~dp0
: Remove the trailing '\'
set ROBOT_HOME_DIR=%ROBOT_HOME_DIR:~0,-1%

: Set the output folder containing the plugins and addons from local dev.
call :getAbsolutePath devOutputDir %ROBOT_HOME_DIR%\..\bin\

set ION_NET_ADDON_DIR=%devOutputDir%\Addons
set ION_NET_PLUGINS_DIR=%devOutputDir%\plugins

set JarDir=%ROBOT_HOME_DIR%\bin\ITAS

if %skipSetup% == 0 call :print Checking for jars:      
	set RobotJar=
	call :setIfJarExists RobotJar robotframework-3.0.jar
	set Jars=
	call :setIfJarExists Jars aopalliance-1.0.jar         
	call :setIfJarExists Jars commons-collections-3.2.jar 
	call :setIfJarExists Jars commons-lang-2.5.jar        
	call :setIfJarExists Jars guava-14.0.1.jar            
	call :setIfJarExists Jars guice-3.0.jar               
	call :setIfJarExists Jars ITAS105d7.jar               
	call :setIfJarExists Jars javalib-core-1.2.1.jar      
	call :setIfJarExists Jars javax.inject-1.jar          
	call :setIfJarExists Jars log4j-1.2.17.jar            
	call :setIfJarExists Jars perfkeys-121.jar
	call :setIfJarExists Jars ojdbc14_g-10.2.0.4.jar
	if "%missingJars%" == "TRUE" (
		echo.
		echo. %robotIndent%FAILED: Missing jars.
		echo.
		echo. %robotIndent%Have you run configure.bat?
		echo. %robotIndent%Are your ITAS jars up-to-date? We are using v105 now.
		goto :exit 2
	)
if %skipSetup% == 0 call :printLine   OK

: Go into the working directory to make robot generate the LOGS (with PSH logs)and MkvDB folders there.
pushd %ROBOT_HOME_DIR%\workingDir
set PYTHONPATH=%PYTHONPATH%;%ROBOT_HOME_DIR%\lib

: Loop through al the tests that were parsed from the arguments
for %%T in (%testList%) do (
	call :printLine Launching tests:                      %%T

	: TODO Create different results files for each test
	java -Xmx1024m -Xbootclasspath/a:%Jars%;%ROBOT_HOME_DIR%\lib -jar %RobotJar% --variable RESOURCES:%ROBOT_HOME_DIR%\resources\ --variable ITAS:%ROBOT_HOME_DIR%\bin\ --outputdir results\ %testCases% %suites% %robotArgs% %ROBOT_HOME_DIR%\%%T
	if not %ERRORLEVEL% == 0 (
		echo.
		echo. %robotIndent%Error '%ERRORLEVEL%' returned from Robot.
		goto :exit 5
	)

	if %showResults% == 1 start /b results\report.html
)

: Leave the working dir and go back where we started
popd
goto:EOF

REM ==== FUNCTIONS ======================================

: Asserts the jar exists and fails if it does not.
: %1 The name of the variable to append to.
: %2 The jar file name
:setIfJarExists
	if %skipSetup% == 0 (
		if not exist %JarDir%\%2 (
			if "%missingJars%" == "" echo. & echo.
			echo. %robotIndent%ERROR: '%JarDir%\%2' is missing.
			set missingJars=TRUE
			goto:EOF
		)
	)
	call set currentValue=%%%1%%
	if "%currentValue%" == "" (
		set "%1=%JarDir%\%2"
	) else (
		set "%1=%currentValue%;%JarDir%\%2"
	)
	goto:EOF

: Converts a relative path to an absolut path.
: %1 The name of the variable to store the result in
: %2 The relative path
:getAbsolutePath
	: Gets the path from the second argument
	SET currentValue=%~dp2
	: Removes the trailing backslash
	SET currentValue=%currentValue:~0,-1%
	SET "%1=%currentValue%"
	goto:EOF


:parseArgs
	SET quiet=0
	SET showResults=1
	SET skipSetup=0
	SET testList=
	SET testCases=
	SET suites=
	SET robotArgs=

	:nextArg
		IF "%1" == "/?" call :printUsageAndExit 0
		IF "%1" == "-?" call :printUsageAndExit 0
		IF "%1" == "/help" call :printUsageAndExit 0
		IF "%1" == "--help" call :printUsageAndExit 0

	    IF "%1" == "--quiet" (
	        SET quiet=1
	        SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "--hide-results" (
	    	SET showResults=0
	    	SHIFT
	    	GOTO :nextArg
	    )
	    IF "%1" == "--skip-setup" (
	        SET skipSetup=1
	        SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "--debug" (
	        SET PricingLaunchDebugger=TRUE
	        SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "--test" (
			SET "testCases=%testCases% -t %1"
	    	SHIFT & SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "-t" (
			SET "testCases=%testCases% -t %2"
	    	SHIFT & SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "--suite" (
			SET "suites=%suites% -s %1"
	    	SHIFT & SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "-s" (
			SET "suites=%suites% -s %2"
	    	SHIFT & SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "-v" (
			SET "robotArgs=%robotArgs% --loglevel DEBUG"
	    	SHIFT
		    GOTO :nextArg
	    )
	    IF "%1" == "-V" (
			SET "robotArgs=%robotArgs% --loglevel TRACE"
	    	SHIFT
		    GOTO :nextArg
	    )


	if "%1" == "" (
		SET testList=%ROBOT_HOME_DIR%\tests\
		goto:EOF
	)

	:buildTestList
	if not "%1" == "" (
		SET "testList=%testList% %1"
		SHIFT
		goto:buildTestList
	)

	goto:EOF


:print
	if %quiet% == 0 (
		set __printing=1
		set /p "=%robotIndent%%~1" <NUL
	)
	goto:EOF


:printLine
	if %quiet% == 0 (
		if "%~1" == "" (
			echo.
		) else (
			if "%__printing%" == "" (
				echo. %~1
			) else (
				echo. %robotIndent%%~1
			)
		)
		set __printing=
	)
	goto:EOF


:printUsageAndExit
	echo Usage: robot [options] [^<test_path^> ...]
	echo.
	echo     options
	echo         -? --help       Prints this information and exits.
	echo         --debug         Attaches the debugger to PXE GUI in the test suite setup.
	echo         --hide-results  Optional. Use to prevent the result document from launching in the browser.
	echo         --quiet         Optional. Reduces the output to a minimum.
	echo         --skip-setup    Skips the steps to validate that jars and dlls are present.
	echo         -t --test       Selects specific test cases. Can be used more than once.
	echo                         See: http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#selecting-test-cases
	echo         -s --suite      Selects specific test suites. Can be used more than once.
	echo                         See: http://robotframework.org/robotframework/latest/RobotFrameworkUserGuide.html#selecting-test-cases
	echo         -v              Sets the Robot log level to DEBUG.
	echo         -V              Sets the Robot log level to TRACE.
	echo         test_path       Optional. Relative path to a folder with robot test files or a specific robot test file.
	echo                         If not used, defaults to:
	echo                             %ROBOT_HOME_DIR%\tests
	echo                         Can pass more than one.
	echo.
	echo Example: robot tests
	echo.
	endlocal
	exit %1

:exit
	endlocal
	exit %1