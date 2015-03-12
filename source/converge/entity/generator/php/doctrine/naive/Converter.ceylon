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
    SymbolName,
    MultiTypeSpec,
    SingleTypeSpec,
    noPackage
}

import de.anhnhan.php.ast {
    Name,
    ClassOrInterface,
    Use,
    Const,
    Class,
    Interface,
    public,
    Method,
    Property,
    PHPExpression=Expression,
    PHPString=StringLiteral,
    phpTrue,
    phpFalse,
    NumberLiteral,
    phpNull,
    _final,
    Function,
    Return,
    thisRef,
    VariableReference,
    FunctionDefinitionParameter,
    Assignment,
    FunctionInvocation,
    varRef,
    FunctionCallArgument,
    propRef,
    private
}

import de.anhnhan.utils {
    ucfirst,
    pipe2,
    actOnNullable,
    falsyFun,
    cast
}

shared
Name toPHPName(SingleTypeSpec type)
{
    assert (is [String+] name = type.inPackage.nameParts.append([type.name]));
    return Name(name, type.inPackage == noPackage);
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
    function defaultMembers(Field field)
            => {
                generateProperty(field),
                generateGetterMethod(field),
                generateSetterMethod(field)
            };
    switch (member)
    case (is Field)
    {
        value typ = member.type;
        switch (typ)
        case (is MultiTypeSpec?)
        {
            return defaultMembers(member);
        }
        case (is SingleTypeSpec)
        {
            switch (typ.name)
            case ("Collection")
            {
                function collectionMethod(String field, String kind)
                        => Method
                        {
                            Function
                            {
                                kind + ucfirst(field);
                                {FunctionDefinitionParameter(field)};
                                FunctionInvocation { propRef(thisRef(field), kind); FunctionCallArgument(varRef(field)) },
                                Return(VariableReference("this"))
                            };
                            _final, public
                        };

                return {
                    Property
                    {
                        member.name;
                        annotations = doctrineAnnotations(member);
                    },
                    generateGetterMethod(member),
                    collectionMethod(member.name, "add"),
                    collectionMethod(member.name, "remove"),
                    collectionMethod(member.name, "has")
                };
            }
            case ("ExternalReference")
            {
                value object_attr = member.name + "_object";
                return {
                    Property { member.name; annotations = doctrineAnnotations(member); },
                    Property(object_attr),
                    Method
                    {
                        Function
                        {
                            member.name;
                            statements = {
                                Return(thisRef(object_attr))
                            };
                        };
                        _final, public
                    },
                    Method
                    {
                        Function
                        {
                            member.name + "Id";
                            statements = {
                                Return(thisRef(member.name))
                            };
                        };
                        _final, public
                    },
                    Method
                    {
                        Function
                        {
                            "set" + ucfirst(member.name);
                            {FunctionDefinitionParameter(member.name)};
                            Assignment(thisRef(member.name), propRef(varRef(member.name), "uid")),
                            Assignment(thisRef(object_attr), varRef(member.name)),
                            Return(VariableReference("this"))
                        };
                        _final, member.mutable then public else private
                    }
                }.coalesced;
            }
            else
            {
                return defaultMembers(member);
            }
        }
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

    value fieldIsCollection = falsyFun(pipe2(Field.type, pipe2(cast<SingleTypeSpec>, actOnNullable(pipe2(SingleTypeSpec.name, "Collection".equals)))));

    value fieldsToBeInitialized = fields
            .filter(Field.immutable)
            .filter(not(Field.autoInitialize))
            .filter(not(pipe2(Field.name, specialValueFields.contains)))
            .filter(not(fieldIsCollection))
    ;
    value fieldsToAutoInitialize = fields.filter(Field.autoInitialize);
    value fieldCollections = fields.filter(fieldIsCollection);

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
                    parameters = fieldsToBeInitialized*.name.map(`FunctionDefinitionParameter`)
                            .chain(fieldCollections*.name.map((name) => FunctionDefinitionParameter { name; typeHint = doctrineCollection; }))
                    ;
                    statements = fieldsToBeInitialized.chain(fieldCollections)
                            .map((field) => Assignment(thisRef(field.name), VariableReference(field.name)))
                            .chain(fieldsToAutoInitialize
                                    .map((field) => Assignment(thisRef(field.name), autoInitValueFor(field))))
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
    return Property(name, defaultValue, modifiers, doctrineAnnotations(field));
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
            name = "set" + ucfirst(field.name);
            parameters = [FunctionDefinitionParameter(field.name)];
            statements = [
                Assignment(thisRef(field.name), VariableReference(field.name)),
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
