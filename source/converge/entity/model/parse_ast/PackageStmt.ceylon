/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface PackageStmt
        of noPackage | InPackage
{
    shared formal
    String[] nameParts;
}

shared
interface InPackage
        satisfies PackageStmt
{
    shared actual formal
    [String+] nameParts;
}

shared object noPackage satisfies PackageStmt { shared actual [] nameParts = []; }

shared
PackageStmt packageStmt([String+] packageNameParts)
{
    object packageStmt
            satisfies InPackage
    {
        nameParts = packageNameParts;
    }
    return packageStmt;
}
