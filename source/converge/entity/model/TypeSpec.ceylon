/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface TypeSpec
        satisfies Expression
{
    shared formal
    String name;

    "Template parameters."
    shared formal
    Expression[] parameters;
}

shared
TypeSpec typeSpec(String typeName, Expression[] typeParameters)
{
    object typeSpec
            satisfies TypeSpec
    {
        name = typeName;
        parameters = typeParameters;
    }
    return typeSpec;
}
