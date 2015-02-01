/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Literal
        of StringLiteral | IntegerLiteral
        satisfies Expression
{
    shared formal
    String|Integer contents;
}

shared
interface StringLiteral
        satisfies Literal
{
    shared actual formal
    String contents;
}

shared
interface IntegerLiteral
        satisfies Literal
{
    shared actual formal
    Integer contents;
}

shared
StringLiteral stringLiteral(String str)
{
    object stringLiteral
            satisfies StringLiteral
    {
        contents = str;
    }
    return stringLiteral;
}

shared
IntegerLiteral integerLiteral(Integer int)
{
    object integerLiteral
            satisfies IntegerLiteral
    {
        contents = int;
    }
    return integerLiteral;
}
