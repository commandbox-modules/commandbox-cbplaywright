component {

    property name="driverService" inject="DriverService@commandbox-cbplaywright";

    function run( string version = "latest", boolean force = false ) {
        variables.driverService.installDriver(
            arguments.version,
            expandPath( "/commandbox-cbplaywright" ),
            arguments.force,
            print
        );
    }

}
