component {

    function configure() {
    }

    function onLoad() {
        var fullModulePath = modulePath.replace( "\", "/", "all" ) & ( modulePath.endswith( "/" ) ? "" : "/" );
        wirebox.getInstance( "DriverService@commandbox-cbplaywright" ).installDriver( "1.52.0", fullModulePath );
    }

}
