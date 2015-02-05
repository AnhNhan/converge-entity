/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Literal
        of StringLiteral | IntegerLiteral | BooleanLiteral | NullLiteral
        satisfies Expression
{
    shared formal
    String|Integer|Boolean|Null contents;
}

shared
interface StringLiteral
        satisfies Literal
{
    shared actual formal
    String contents;

    string => "\"``contents``\"";
}

shared
interface IntegerLiteral
        satisfies Literal
{
    shared actual formal
    Integer contents;

    string => contents.string;
}

shared
interface BooleanLiteral
        of trueLiteral | falseLiteral
        satisfies Literal
{
    shared actual formal
    Boolean contents;

    string => contents.string;
}

shared
interface NullLiteral
        of nullLiteral
        satisfies Literal
{
    shared actual formal
    Null contents;

    string => "null";
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

shared object trueLiteral satisfies BooleanLiteral { contents = true; }
shared object falseLiteral satisfies BooleanLiteral { contents = false; }

shared
BooleanLiteral booleanLiteral(Boolean contents)
        => contents then trueLiteral else falseLiteral;

shared object nullLiteral satisfies NullLiteral { contents = null; }
