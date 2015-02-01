/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface PackageStmt
{
    shared formal
    [String+] nameParts;
}

shared
PackageStmt packageStmt([String+] packageNameParts)
{
    object packageStmt
            satisfies PackageStmt
    {
        nameParts = packageNameParts;
    }
    return packageStmt;
}
