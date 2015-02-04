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
TypeSymbol typeSymbol(String symbolName)
{
    object symbol
            satisfies TypeSymbol
    {
        name = symbolName;
    }
    return symbol;
}

shared
ValueSymbol valueSymbol(String symbolName)
{
    object symbol
            satisfies ValueSymbol
    {
        name = symbolName;
    }
    return symbol;
}
