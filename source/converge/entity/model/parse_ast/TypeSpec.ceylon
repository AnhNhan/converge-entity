/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface TypeSpec
        of MultiTypeSpec | SingleTypeSpec
        satisfies Expression
{}

"A.k.a. type unions."
shared
interface MultiTypeSpec
        satisfies TypeSpec
{
    shared formal
    [SingleTypeSpec+] typeSpecs;

    string => typeSpecs*.string.interpose("|").fold("")(plus<String>);
}

shared
MultiTypeSpec multiTypeSpec([SingleTypeSpec+] speccedTypes)
{
    object multiTypeSpec
            satisfies MultiTypeSpec
    {
        typeSpecs = speccedTypes;
    }
    return multiTypeSpec;
}

shared
interface SingleTypeSpec
        satisfies TypeSpec
{
    shared formal
    String name;

    shared formal
    PackageStmt inPackage;

    "Template parameters."
    shared formal
    Expression[] parameters;

    string => (inPackage == noPackage then "" else inPackage.nameParts.interpose(".").fold("")(plus<String>) + "::")
            + "``name````!parameters.empty then "<" + parameters*.string.interpose(", ").fold("")(plus<String>) + ">" else ""``";
}

shared
SingleTypeSpec singleTypeSpec(String typeName, Expression[] typeParameters, PackageStmt packag = noPackage)
{
    object typeSpec
            satisfies SingleTypeSpec
    {
        name = typeName;
        parameters = typeParameters;
        inPackage = packag;
    }
    return typeSpec;
}
