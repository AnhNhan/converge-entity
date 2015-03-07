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
    public,
    Const,
    Method,
    Property,
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
    thisRef,
    Name,
    VariableReference,
    FunctionDefinitionParameter,
    ExpressionStatement,
    Assignment,
    Use
}

// TODO: Include parents + transactions for reification & generation
shared
ClassOrInterface convertStruct(Struct struct)
{
    value members = struct.members
            .flatMap(generateMember)
            .coalesced
            .chain(generateCommonMethods { for (member in struct.members) if (is Field member) member })
            // For now, hardcoded
            .chain([Use({Name(["AnhNhan", "Converge", "Infrastructure", "MagicGetter"], false)->null})])
    ;

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
        return {
            generateProperty(member),
            generateGetterMethod(member),
            generateSetterMethod(member)
        };
    }
    case (is FunctionCall)
    {
        // Ignore
        return {null};
    }
}

"Generates common methods like the constructor, certain kinds of update methods
 etc."
{Method*} generateCommonMethods({Field*} fields)
{
    value specialValueFields = ["id", "uid"];

    value fieldsToBeInitialized = fields
            .filter(Field.immutable)
            .filter(not(Field.autoInitialize))
            .filter(not((Field field) => field.name in specialValueFields))
    ;
    value fieldsToAutoInitialize = fields.filter(Field.autoInitialize);

    variable
    {Method*} methods = {};

    if (fieldsToBeInitialized.size + fieldsToAutoInitialize.size > 0)
    {
        methods = methods.chain
        {
            Method
            {
                modifiers = {public};
                func = Function
                {
                    name = "__construct";
                    parameters = fieldsToBeInitialized*.name.map(`FunctionDefinitionParameter`);
                    statements = fieldsToBeInitialized
                            .map((field) => ExpressionStatement(Assignment(thisRef(field.name), VariableReference(field.name))))
                            .chain(fieldsToAutoInitialize
                                    .map((field) => ExpressionStatement(Assignment(thisRef(field.name), autoInitValueFor(field)))))
                    ;
                };
            }
        };
    }

    return methods;
}

Property generateProperty(Field field)
{
    value name = field.name;
    PHPExpression? defaultValue = field.defaultValue exists then convertExpression(field.defaultValue else nothing);
    value modifiers = {}; // TODO: Temporary
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
            statements = [Return(thisRef(field.name))];
        };
        modifiers = {_final, public};
    };
}

Method? generateSetterMethod(Field field)
{
    if (field.immutable)
    {
        return null;
    }

    return Method
    {
        func = Function
        {
            name = "set" + String { {field.name.first?.uppercased, *field.name.rest}.coalesced; };
            parameters = [FunctionDefinitionParameter(field.name)];
            statements = [
                ExpressionStatement(Assignment(thisRef(field.name), VariableReference(field.name))),
                Return(VariableReference("this"))
            ];
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
