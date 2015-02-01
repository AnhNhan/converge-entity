/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface SymbolName
        of RelativeSymbol | FullyQualifiedSymbol
        satisfies Expression
{
    shared formal
    String name;

    shared formal
    String[]? namespace;

    "Whether this symbol is definitely at the top-level."
    shared default
    Boolean topLevel => namespace?.empty else false;
}

shared
interface RelativeSymbol
        satisfies SymbolName
{
    shared actual
    Null namespace => null;

    shared formal variable
    FullyQualifiedSymbol? resolvedSymbol;
}

shared
interface FullyQualifiedSymbol
        satisfies SymbolName
{
    shared actual formal
    String[] namespace;
}

shared
RelativeSymbol relativeSymbol(String _name)
{
    object relativeSymbol
            satisfies RelativeSymbol
    {
        name = _name;

        shared actual variable
        FullyQualifiedSymbol? resolvedSymbol = null;
    }
    return relativeSymbol;
}

shared
FullyQualifiedSymbol fullyQualifiedSymbol(String _name, String[] _namespace)
{
    object fullyQualifiedSymbol
            satisfies FullyQualifiedSymbol
    {
        name = _name;
        namespace = _namespace;
    }
    return fullyQualifiedSymbol;
}
