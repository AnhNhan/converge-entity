/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface FunctionCall
        satisfies Expression
{
    shared formal
    String name;

    shared formal
    PackageStmt inPackage;

    "Invokation arguments."
    shared formal
    Expression[] arguments;

    "Template parameters."
    shared formal
    Expression[] parameters;

    string => "``name````!parameters.empty then "<" + parameters*.string.interpose(", ").fold("")(plus<String>) + ">" else ""``(``arguments*.string.interpose(", ").fold("")(plus<String>)``)";
}

shared
FunctionCall functionCall(String funcName, Expression[] typeParameters, Expression[] invokationArguments, PackageStmt packag = noPackage)
{
    object functionCall
            satisfies FunctionCall
    {
        name = funcName;
        inPackage = packag;
        parameters = typeParameters;
        arguments = invokationArguments;
    }
    return functionCall;
}
