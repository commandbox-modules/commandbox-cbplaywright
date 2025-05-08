component {

    property name="driverService" inject="DriverService@commandbox-cbplaywright";

    function run(
        string version = "latest",
        string directory = expandPath( "/commandbox-cbplaywright" ),
        boolean force = false
    ) {
        variables.driverService.installDriver(
            arguments.version,
            arguments.directory,
            arguments.force,
            print
        );
    }

}
