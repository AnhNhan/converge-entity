/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface SymbolName
        of TypeSymbol | ValueSymbol
        satisfies Expression
{
    shared formal
    String name;

    shared formal
    PackageStmt packageSpec;

    string => packageSpec == noPackage then name else "``packageSpec.nameParts.interpose(".").fold("")(plus<String>)``::``name``";

    shared actual default
    Boolean equals(Object that) {
        if (is SymbolName that)
        {
            return name==that.name &&
                packageSpec==that.packageSpec;
        }
        else
        {
            return false;
        }
    }

    hash => name.hash * 31 + packageSpec.hash * 31 + className(this).hash * 31;
}

shared
interface TypeSymbol
        satisfies SymbolName
{
    shared actual
    Boolean equals(Object that)
    {
        if (is TypeSymbol that)
        {
            return (this of SymbolName).equals(that);
        }
        else
        {
            return false;
        }
    }
}

shared
interface ValueSymbol
        satisfies SymbolName
{
    // Poor man's expr-if
    equals(Object that) => ![for (obj in [that]) if (is ValueSymbol obj) obj].empty then (this of SymbolName).equals(that) else false;
}

shared
SymbolName symbolName(String symbolName, PackageStmt specifiedPackage = noPackage)
{
    switch (symbolName.first?.lowercase)
    case (true)
    {
        return valueSymbol(symbolName, specifiedPackage);
    }
    case (false)
    {
        return typeSymbol(symbolName, specifiedPackage);
    }
    case (null)
    {
        throw Exception("Empty identifier string.");
    }
}

shared
TypeSymbol typeSymbol(String symbolName, PackageStmt specifiedPackage = noPackage)
{
    object symbol
            extends Object()
            satisfies TypeSymbol
    {
        name = symbolName;
        packageSpec = specifiedPackage;
    }
    return symbol;
}

shared
ValueSymbol valueSymbol(String symbolName, PackageStmt specifiedPackage = noPackage)
{
    object symbol
            extends Object()
            satisfies ValueSymbol
    {
        name = symbolName;
        packageSpec = specifiedPackage;
    }
    return symbol;
}
