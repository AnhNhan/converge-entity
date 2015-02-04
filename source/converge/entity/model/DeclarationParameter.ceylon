/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface DeclarationParameter
        of DeclarationTypeParameter | DeclarationValueParameter
{
    shared formal
    String name;

    shared formal
    TypeSpec? typeSpec;

    shared formal
    Expression? defaultValue;
}

shared
interface DeclarationTypeParameter
        satisfies DeclarationParameter
{
    shared actual formal
    TypeSpec? defaultValue;
}

shared
interface DeclarationValueParameter
        satisfies DeclarationParameter
{
    shared actual formal
    Literal|FunctionCall|SymbolName? defaultValue;
}

shared
DeclarationParameter declarationParameter(String paramName, TypeSpec? _typeSpec, Expression? _defaultValue)
{
    switch (paramName.first?.lowercase)
    case (true)
    {
        assert (is Literal|FunctionCall|SymbolName? _defaultValue);
        object declarationValueParameter
                satisfies DeclarationValueParameter
        {
            name = paramName;
            typeSpec = _typeSpec;
            defaultValue = _defaultValue;
        }
        return declarationValueParameter;
    }
    case (false)
    {
        assert (is TypeSpec? _defaultValue);
        object declarationTypeParameter
                satisfies DeclarationTypeParameter
        {
            name = paramName;
            typeSpec = _typeSpec;
            defaultValue = _defaultValue;
        }
        return declarationTypeParameter;
    }
    case (null)
    {
        throw Exception("Empty parameter name.");
    }
}
