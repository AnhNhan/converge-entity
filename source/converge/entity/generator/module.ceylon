/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

native("jvm") 
module converge.entity.generator "dev"
{
    shared
    import de.anhnhan.php "dev";
    import de.anhnhan.utils "0.1";
    shared
    import converge.entity.model "dev";
    import de.anhnhan.parser "dev";

    import ceylon.collection "1.2.0";
    import ceylon.file "1.2.0";

    optional
    import ceylon.test "1.2.0";
}
