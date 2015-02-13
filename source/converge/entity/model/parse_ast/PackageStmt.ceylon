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

    shared actual
    Boolean equals(Object that)
    {
        if (is PackageStmt that)
        {
            return nameParts == that.nameParts;
        }
        else
        {
            return false;
        }
    }

    shared actual
    Integer hash
    {
        variable value hash = 1;
        hash = 31*hash + nameParts.hash;
        return hash;
    }
}

shared
interface InPackage
        satisfies PackageStmt
{
    shared actual formal
    [String+] nameParts;
}

shared object noPackage extends Object() satisfies PackageStmt { shared actual [] nameParts = []; }

shared
PackageStmt packageStmt([String+] packageNameParts)
{
    object packageStmt
            extends Object()
            satisfies InPackage
    {
        nameParts = packageNameParts;
    }
    return packageStmt;
}
