/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface ScopedSymbolStack<Element>
        given Element satisfies Object
{
    shared formal
    ScopedSymbolStack<Element>? parentSymbolStack;

    shared formal
    Map<String, Element> symbols;

    shared
    Target? searchSymbol<Target = Element>(String name)
            given Target satisfies Element
    {
        if (exists symbol = symbols[name])
        {
            assert (is Target symbol);
            return symbol;
        }
        return parentSymbolStack?.searchSymbol<Target>(name);
    }
}
