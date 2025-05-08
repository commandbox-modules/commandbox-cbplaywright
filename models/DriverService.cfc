component {

    property name="progressableDownloader" inject="ProgressableDownloader";
    property name="progressBarGeneric" inject="ProgressBarGeneric";
    property name="consoleLogger" inject="logbox:logger:console";
    property name="javaSystem" inject="java:java.lang.System";
    property name="progressBar" inject="ProgressBar";
    property name="wirebox" inject="wirebox";
    property name="fs" inject="Filesystem";

    public void function installDriver(
        required string version,
        required string baseDirectory,
        boolean force = false,
        any print
    ) {
        if ( arguments.version == "latest" ) {
            try {
                cfhttp(
                    url = "https://search.maven.org/solrsearch/select?q=g:com.microsoft.playwright+AND+a:driver-bundle&core=gav&rows=20&wt=json",
                    encodeURL = false,
                    timeout = 15
                );
                // catch non expected status codes
                if ( cfhttp.status_code != 200 ) {
                    throw( "Oops! search.maven.org responsed with an unexpected satus code: #cfhttp.status_code#", "UnexpectedStatus" );
                }
                var res = deserializeJSON( cfhttp.filecontent ).response;
                if ( res.numFound <= 0 ) {
                    throw( "No results found for com.microsoft.playwright:driver-bundle" );
                }
                arguments.version = res.docs[ 1 ].v;
            } catch ( UnexpectedStatus e ) {
                throw( e.message );
            } catch ( any e ) {
                throw( "Error finding latest version of com.microsoft.playwright:driver-bundle", e );
            }
        }

        var driverDirectory = getDriverDirectory( arguments.baseDirectory );

        if ( directoryExists( driverDirectory ) ) {
            if ( arguments.force ) {
                if ( !isNull( arguments.print ) ) {
                    arguments.print.redLine( "Removing the current driver due to the --force flag." );
                }
                directoryDelete( driverDirectory, true );
            } else {
                if ( !isNull( arguments.print ) ) {
                    var driverVersion = deserializeJSON( fileRead( driverDirectory & "package/package.json" ) ).version;
                    arguments.print.line( "A Playwright driver [#driverVersion#] is already installed." );
                    arguments.print.redLine( "Run with the --force flag to overwrite." );
                }
                return;
            }
        }

        var tmpDirectory = arguments.baseDirectory & "/tmp/";

        directoryCreate( tmpDirectory, true, true );

        var job = wirebox.getInstance( "InteractiveJob" );
        job.start( "Playwright driver not found.  Please wait for a moment while the correct driver for your platform is downloaded." );

        var jarDownloadUrl = "https://search.maven.org/remotecontent?filepath=com/microsoft/playwright/driver-bundle/#arguments.version#/driver-bundle-#arguments.version#.jar";
        var tmpJarFileName = tmpDirectory & "driver-bundle-#arguments.version#.jar";

        job.addLog( "Downloading driver from [#jarDownloadUrl#]" );

        try {
            variables.progressableDownloader.download(
                jarDownloadUrl,
                tmpJarFileName,
                function( status ) {
                    variables.progressBar.update( argumentCollection = status );
                }
            );

            job.addLog( "Unzipping the drivers" );
            var tmpUnpackedJar = tmpDirectory & "driver-bundle";
            cfzip( action = "unzip", file = tmpJarFileName, destination = tmpUnpackedJar );

            job.addLog( "Extracting the drivers for [#getPlatformName()#]" );
            directoryCopy( "#tmpUnpackedJar#/driver/#getPlatformName()#", driverDirectory, true );

            job.addLog( "Cleaning up temporary files" );
            directoryDelete( tmpUnpackedJar, true );
            fileDelete( tmpJarFileName );

            if ( !fileExists( driverDirectory & "playwright.sh" ) ) {
                if ( variables.fs.isWindows() ) {
                    job.addLog( "Adding playwright.bat file..." );
                    fileCopy( arguments.baseDirectory & "/models/playwright.cmd.template", driverDirectory & "playwright.cmd" );
                } else {
                    job.addLog( "Adding playwright.sh file..." );
                    fileCopy( arguments.baseDirectory & "/models/playwright.sh.template", driverDirectory & "playwright.sh" );
                }
            }

            job.addLog( "Setting the correct permissions for the driver files..." );
            var files = directoryList( driverDirectory, true );
            var fileCount = files.len();
            variables.progressBarGeneric.update( percent = 0 );
            files.each( ( fileName, i ) => {
                fileSetAccessMode( fileName, "777" );
                variables.progressBarGeneric.update( percent = ( i / fileCount ) * 100 );
            } );
            job.addLog( "Driver downloaded and extracted successfully." );

            // delete the temp dir, we don't need it anymore
            directoryDelete( tmpDirectory, true );

            job.complete();
            if ( !isNull( arguments.print ) ) {
                arguments.print.greenLine( "Playwright driver [#arguments.version#] downloaded and extracted successfully." );
            }
        } catch ( any var e ) {
            job.addErrorLog( "Unable to download the driver:" );
            job.addErrorLog( "#e.message##chr( 10 )##e.detail#" );
            job.addLog( "Please manually place the driver here:" );
            job.addLog( driverDirectory );

            // Remove any partial download.
            if ( directoryExists( driverDirectory ) ) {
                directoryDelete( driverDirectory, true );
            }
            if ( directoryExists( tmpDirectory ) ) {
                directoryDelete( tmpDirectory, true );
            }
            job.error( dumplog = true );
        }
    }

    public string function getExecutablePath( required string baseDirectory ) {
        var executableName = variables.fs.isWindows() ? "playwright.cmd" : "playwright.sh";
        return '"' & getDriverDirectory( arguments.baseDirectory ) & executableName & '"';
    }

    private string function getDriverDirectory( required string baseDirectory ) {
        return arguments.baseDirectory & "/driver/";
    }

    private string function getPlatformName() {
        if ( variables.fs.isWindows() ) {
            return "win32_x64";
        } else if ( variables.fs.isMac() ) {
            return "mac";
        } else if ( variables.fs.isLinux() ) {
            // detect the architecture
            var arch = lCase( variables.javaSystem.getProperty( "os.arch" ) );
            if ( arch == "aarch64" ) {
                return "linux-arm64";
            } else {
                return "linux";
            }
        } else {
            throw( "Unsupported platform" );
        }
    }

}
