/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import converge.entity.model.parse_ast {
    Struct,
    Field,
    FunctionCall,
    Expression,
    IntegerLiteral,
    StringLiteral,
    trueLiteral,
    falseLiteral,
    TypeSpec,
    nullLiteral,
    SymbolName
}

import de.anhnhan.php.ast {
    Class,
    Interface,
    Property,
    public,
    Const,
    Method,
    PHPExpression=Expression,
    PHPString=StringLiteral,
    phpTrue,
    phpFalse,
    NumberLiteral,
    phpNull,
    ClassOrInterface,
    _final,
    Function,
    Return,
    PropertyReference,
    VariableReference
}

// TODO: Include parents + transactions for reification & generation
shared
ClassOrInterface convertStruct(Struct struct)
{
    value members = struct.members.flatMap(generateMember).coalesced;

    // TODO: Temporary
    value implements = [];
    value _extends = null;

    switch (struct.abstract)
    case (true)
    {
        value modifiers = [];
        return Interface
        {
            name = struct.name;
            modifiers = modifiers;
            implements = implements;
            statements = members;
        };
    }
    case (false)
    {
        // No final/abstract modifier
        value modifiers = [];
        return Class
        {
            name = struct.name;
            modifiers = modifiers;
            _extends = _extends;
            implements = implements;
            statements = members;
        };
    }
}

{Property|Const|Method|Null*} generateMember(Field|FunctionCall member)
{
    switch (member)
    case (is Field)
    {
        return {generateProperty(member), generateGetterMethod(member)};
    }
    case (is FunctionCall)
    {
        // Ignore
        return {null};
    }
}

Property generateProperty(Field field)
{
    value name = field.name;
    PHPExpression? defaultValue = field.defaultValue exists then convertExpression(field.defaultValue else nothing);
    value modifiers = {public}; // TODO: Temporary
    return Property(name, defaultValue, modifiers);
}

Method generateGetterMethod(Field field)
{
    return Method
    {
        func = Function
        {
            name = field.name;
            parameters = [];
            statements = [Return(PropertyReference(VariableReference("this"), field.name))];
        };
        modifiers = {_final, public};
    };
}

PHPExpression convertExpression(Expression expr)
{
    switch (expr)
    case (is IntegerLiteral)
    {
        return NumberLiteral(expr.contents);
    }
    case (is StringLiteral)
    {
        return PHPString(expr.contents);
    }
    case (trueLiteral)
    {
        return phpTrue;
    }
    case (falseLiteral)
    {
        return phpFalse;
    }
    case (nullLiteral)
    {
        return phpNull;
    }
    case (is FunctionCall | TypeSpec | SymbolName)
    {
        "Unsupported in PHP."
        assert (false);
    }
}
