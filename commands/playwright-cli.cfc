component aliases="playwright" {

    property name="driverService" inject="DriverService@commandbox-cbplaywright";

    function run() {
        var cmd = variables.driverService.getExecutablePath( expandPath( "/commandbox-cbplaywright" ) );

        var i = 0;
        while ( !isNull( arguments[ ++i ] ) ) {
            cmd &= " #arguments[ i ]#";
        }

        print.toConsole();
        var output = command( "run" )
            .params( cmd )
            // Try to contain the output if we're in an interactive job and there are arguments (no args opens the cfpm shell)
            .run( echo = true, returnOutput = ( job.isActive() && arguments.count() ) );

        if ( job.isActive() && arguments.count() ) {
            print.line( output );
        }
    }

}
