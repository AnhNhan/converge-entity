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
    noPackage,
    PackageStmt,
    singleTypeSpec,
    InPackage
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
    private,
    parent,
    staticRef,
    Namespace
}
import de.anhnhan.utils {
    ucfirst,
    pipe2,
    actOnNullable,
    falsyFun,
    cast,
    pickOfType
}

shared
Name toPHPName(SingleTypeSpec type)
{
    assert (nonempty name = type.inPackage.nameParts.append([type.name]));
    return Name(name, type.inPackage == noPackage);
}

// TODO: Include transactions for concretization & generation
shared
ClassOrInterface|Namespace convertStruct(
    "The struct to convert."
    Struct struct,
    "Responsible for the retrieval of referenced structs."
    Struct? getParents(SingleTypeSpec typeSpec),
    "Used to declare the current PHP namespace and resolve relative types."
    PackageStmt currentPackage = noPackage
)
{
    value converted = convertStructReal(struct, getParents, currentPackage);
    // Why does a switch statement not work? (noPackage not assignable to Identifyable?)
    if (currentPackage == noPackage)
    {
        return converted;
    }
    else if (is InPackage currentPackage)
    {
        return Namespace(Name(currentPackage.nameParts), {converted});
    }
    else
    {
        assert (false);
    }
}

ClassOrInterface convertStructReal(
    "The struct to convert."
    Struct struct,
    "Responsible for the retrieval of referenced structs."
    Struct? getParents(SingleTypeSpec typeSpec),
    "Used to declare the current PHP namespace and resolve relative types."
    PackageStmt currentPackage = noPackage
)
{
    switch (struct.abstract)
    case (true)
    {
        return convertToInterface(struct);
    }
    case (false)
    {
        return convertToClass(struct, getParents, currentPackage);
    }
}

Interface convertToInterface(Struct struct)
{
    assert (struct.abstract);

    value parent = struct.concretizing;
    Name[] implements;
    if (exists parent)
    {
        implements = [toPHPName(singleTypeSpec(parent.name, [], parent.inPackage))];
    }
    else
    {
        implements = [];
    }

    value modifiers = [];
    return Interface
    {
        name = struct.name;
        modifiers = modifiers;
        implements = implements;
        statements = pickOfType<Field>(struct.members)
        //.filter(Field.abstract)
                .map((field) => Method
            {
            func = Function
            {
                field.name;
            };
            inInterface = true;
            public
        })
        ;
    };
}

Class convertToClass(Struct struct, Struct? getParents(SingleTypeSpec typeSpec), PackageStmt currentPackage)
{
    assert (!struct.abstract);

    if (!struct.parameters.empty)
    {
        throw Exception("Struct ``struct.name`` declares type parameters, but is not abstract. We would not know how to concretize it.");
    }

    value _struct = concretizeStruct(struct, getParents, currentPackage);
    value members = _struct.members
            .flatMap(generateMember)
            .coalesced
            .chain(generateCommonMethods(_struct))
            // For now, hardcoded
            .chain([Use({Name(["AnhNhan", "Converge", "Infrastructure", "MagicGetter"], false)->null})])
    ;

    Name[] implements;
    Name? _extends;

    if (exists parent = _struct.concretizing)
    {
        if (exists result = resolveSpec(parent, currentPackage, getParents))
        {
            value resultSpec = singleTypeSpec(result.item.name, [], result.key);
            if (result.item.abstract)
            {
                implements = [toPHPName(resultSpec)];
                _extends = null;
            }
            else
            {
                implements = [];
                _extends = toPHPName(resultSpec);
            }
        }
        else
        {
            throw Exception("Could not find struct ``parent``.");
        }
    }
    else
    {
        implements = [];
        _extends = null;
    }

    // No final/abstract modifier, Doctrine creates proxies that derive from
    // the entity class
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

                // TODO: Inflect methods to be singular
                return {
                    Property
                    {
                        member.name;
                        annotations = doctrineAnnotations(member);
                    },
                    generateGetterMethod(member),
                    collectionMethod(member.name, "add"),
                    collectionMethod(member.name, "remove"),
                    Method
                    {
                        Function
                        {
                            "has" + ucfirst(member.name);
                            {FunctionDefinitionParameter(member.name)};
                            Return(FunctionInvocation { propRef(thisRef(member.name), "has"); FunctionCallArgument(varRef(member.name)) })
                        };
                        _final, public
                    }
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
{Method*} generateCommonMethods(Struct struct)
{
    value fields = pickOfType<Field>(struct.members);
    value specialValueFields = ["id", "uid"];

    value fieldIsCollection = falsyFun(pipe2(Field.type, pipe2(cast<SingleTypeSpec>, actOnNullable(pipe2(SingleTypeSpec.name, "Collection".equals)))));

    value fieldsToBeInitialized = fields
            .filter(Field.immutable)
            .filter(not(Field.autoInitialize))
            .filter(not(pipe2(Field.name, specialValueFields.contains)))
            .filter(not(fieldIsCollection))
    ;
    value fieldsToAutoInitialize = fields.filter(Field.autoInitialize);
    value fieldsToReinitialize = fields.filter(Field.reinitOnUpdate);
    value fieldCollections = fields.filter(fieldIsCollection);
    value fieldUid = fields.find(pipe2(Field.name, "uid".equals));

    function initializeField(Field field)
            => Assignment(thisRef(field.name), autoInitValueFor(field));

    variable
    {Method*} methods = {
        Method
        {
            modifiers = {public};
            func = Function {
                name = "update";
                statements = fieldsToReinitialize.map(initializeField)
                        .chain(struct.concretizing exists
                                    then {
                                        FunctionInvocation(staticRef(parent, "update"), [])
                                    }
                                    else {}
                        )
                ;
            };
        }
    };

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
                                    .map(initializeField))
                    ;
                };
            }
        };
    }

    if (exists fieldUid)
    {
        // TODO: Better error handling
        assert (is SingleTypeSpec type = fieldUid.type);
        assert (type.name == "UniqueId");
        value params = type.parameters;
        String uidType = "-".join(params.map((expr) => if (is StringLiteral expr) then expr.contents else "<invalid-param>"));

        methods = methods.chain
        {
            Method
            {
                modifiers = {_final, public};
                func = Function
                {
                    name = "uidType";
                    statements = {
                        Return(PHPString(uidType))
                    };
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
