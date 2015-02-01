/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Alias
{
    shared formal
    String name;

    "When only one type, it's a regular substitution. If there are multiple
     types, it's a type union."
    shared formal
    [TypeSpec+] types;
}

shared
Alias typeAlias(String aliasName, [TypeSpec+] aliasedTypes)
{
    object typeAlias
            satisfies Alias
    {
        name = aliasName;
        types = aliasedTypes;
    }
    return typeAlias;
}
