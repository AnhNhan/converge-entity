/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Alias
        satisfies Node
{
    shared formal
    String name;

    "When only one type, it's a regular substitution. If there are multiple
     types, it's a type union."
    shared formal
    [SingleTypeSpec+] types;

    string => "alias ``name`` ``types``";
}

shared
Alias typeAlias(String aliasName, [SingleTypeSpec+] aliasedTypes)
{
    object typeAlias
            satisfies Alias
    {
        name = aliasName;
        types = aliasedTypes;
    }
    return typeAlias;
}
