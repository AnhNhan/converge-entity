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

    string => name;
}

shared
interface TypeSymbol
        satisfies SymbolName
{}

shared
interface ValueSymbol
        satisfies SymbolName
{}

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
            satisfies ValueSymbol
    {
        name = symbolName;
        packageSpec = specifiedPackage;
    }
    return symbol;
}
