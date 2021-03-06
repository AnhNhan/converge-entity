/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    LinkedList,
    HashSet,
    HashMap
}
import ceylon.test {
    test,
    assertEquals
}

import converge.entity.model.parse_ast {
    createStruct=struct,
    Struct,
    SingleTypeSpec,
    Field,
    abstractStruct,
    field,
    singleTypeSpec,
    noPackage,
    PackageStmt,
    FunctionCall,
    annotationUse,
    Expression,
    integerLiteral,
    packageStmt,
    stringLiteral,
    valueSymbol,
    SymbolName,
    Literal,
    MultiTypeSpec,
    multiTypeSpec,
    TypeSpec,
    AnnotationUse,
    functionCall
}

import de.anhnhan.utils {
    pickOfType,
    pipe2,
    assertHasAssertionError
}

Struct concretizeStruct(
    Struct struct,
    Struct? getParents(SingleTypeSpec typeSpec),
    PackageStmt currentPackage = noPackage,
    Expression[] parameters = [],
    String[] concretizationHierarchy = []
)
{
    value members = LinkedList<Field|FunctionCall>();
    value appended_members = LinkedList<Field|FunctionCall>();
    value original_members = struct.members;
    value original_fields = pickOfType<Field>(struct.members);
    value parentSpec = struct.concretizing;
    if (exists parentSpec)
    {
        PackageStmt parentPackage;
        // Resolve structs indepent of type parameters
        Struct parent;
        if (exists result = resolveSpec(parentSpec, currentPackage, getParents))
        {
            parentPackage = result.key;
            parent = result.item;
        }
        else
        {
            throw Exception("Struct ``struct.name`` (package ``currentPackage.nameParts``) concretizes struct ``parentSpec.name``, which does not exist.");
        }

        checkForInheritanceCycles(parent, concretizationHierarchy);

        value concretizedParent = concretizeStruct(parent, getParents, parentSpec.inPackage, parentSpec.parameters, concretizationHierarchy.append([struct.name]));
        if (!concretizedParent.abstract)
        {
            throw Exception("Struct ``struct.name`` concretizes struct ``concretizedParent.name``, which is not abstract.");
        }

        // TODO: Error handling
        value zipped = zipEntries(
            concretizedParent.parameters,
            parentSpec.parameters.chain({ null }.repeat(concretizedParent.parameters.size))
        );
        value template_parameters = HashMap
        {
            entries = { for (entry in zipped) if (exists expr = (if (exists item = entry.item) then item else entry.key.defaultValue)) entry.key.name->expr };
        };
        value parent_members = concretizedParent.members.map((member) => resolveParameterSymbols(member, template_parameters));

        value member_names = original_fields*.name;
        value inherited_fields = pickOfType<Field>(parent_members);
        value inherited_funcalls = pickOfType<FunctionCall>(parent_members);

        appended_members.addAll(
            inherited_fields
                    .filter(Field.appended)
                    .filter(pipe2(Field.name, not(member_names.contains)))
                    .map((field)
                    {
                        if (field.abstract)
                        {
                            throw Exception("Struct ``parent.name`` contains a
                                             field ``field.name`` that is
                                             appended, but it is abstract.
                                             Appended fields can not be abstract
                                             (as that would be pointless, since
                                             it would be overwritten by the
                                             implementation).");
                        }
                        return field;
                    })
        );
        appended_members.addAll(inherited_funcalls);

        checkAndFilterInheritedFields(inherited_fields, member_names, struct, parent)
                .collect(members.add);
    }

    members.addAll(original_members);
    members.addAll(appended_members);

    return createStruct
    {
        struct.name;
        struct.modifiers;
        struct.concretizing;
        struct.parameters;
        members.sequence();
        struct.annotations;
    };
}

"Prevent inheritance cycles, which would cause an infinite loop."
throws(`class ConcretizationCycle`, "when an inheritance cycle is encountered.")
void checkForInheritanceCycles(Struct parent, String[] inheritanceHierarchy)
{
    if (parent.name in inheritanceHierarchy)
    {
        assert (nonempty inheritanceHierarchy);
        throw ConcretizationCycle(parent, inheritanceHierarchy);
    }
}

{Field*} checkAndFilterInheritedFields({Field*} inherited_fields, Category<String> member_names, Struct struct, Struct parent)
        => inherited_fields
                .filter(not(Field.appended))
                // The .map operation is a simple check whether everything has been implemented
                // It simply checks whether an implementation exists, it does not
                // apply any constraints like type checking
                .map((field)
                    {
                        if (field.abstract, !member_names.contains(field.name))
                        {
                            throw Exception("Struct ``struct.name`` concretizes "
                                + "struct ``parent.name``, which declares an abstract "
                                + "field ``field`` that is not implemented in the "
                                + "concretizing struct.");
                        }
                        return field;
                    })
                .filter(pipe2(Field.name, not(member_names.contains)))
        ;

shared
class ConcretizationCycle(
    shared
    Struct struct,
    shared
    [String+] hierarchy
)
        extends Exception("Struct ``struct.name`` concretizes struct ``struct.concretizing?.name else nothing``, which created a cyclic hierarchy. (``hierarchy``)")
{}

Field|FunctionCall resolveParameterSymbols(Field|FunctionCall input, Map<String, Expression> parameters)
{
    if (parameters.empty)
    {
        // No parameters to replace
        return input;
    }

    switch (input)
    case (is Field)
    {
        value type = if (exists input_type = input.type) then resolveParameterSymbolsForTypeSpec(input_type, parameters) else null;

        // TODO: Process annotations
        AnnotationUse[] annotations = input.annotations;

        return field
        {
            fieldName = input.name;
            fieldType = type;
            fieldDefaultValue = resolveExpression<Expression>(input.defaultValue, parameters);
            fieldAnnotations = annotations;
            fieldModifiers = input.modifiers;
        };
    }
    case (is FunctionCall)
    {
        value funcParams = input.parameters.collect((param) => resolveExpression<Expression, Nothing>(param, parameters));
        value funcArgs = input.arguments.collect((arg) => resolveExpression<Expression, Nothing>(arg, parameters));
        return functionCall
        {
            funcName = input.name;
            packag = input.inPackage;
            typeParameters = funcParams;
            invokationArguments = funcArgs;
        };
    }
}

Expression|Absent resolveExpression<Expr, Absent = Null>(Expr|Absent expresssion, Map<String, Expression> parameters)
        given Expr satisfies Expression
        given Absent satisfies Null
{
    switch (expresssion)
    case (is FunctionCall)
    {
        assert (is FunctionCall resolved_function_call = resolveParameterSymbols(expresssion, parameters));
        return resolved_function_call;
    }
    case (is TypeSpec)
    {
        return resolveParameterSymbolsForTypeSpec(expresssion, parameters);
    }
    case (is SymbolName)
    {
        return resolveParameter<Expression, Nothing>(expresssion.name, expresssion, parameters);
    }
    case (is Literal|Absent)
    {
        return expresssion;
    }
}

TypeSpec resolveParameterSymbolsForTypeSpec(TypeSpec typeSpec, Map<String, Expression> parameters)
{
    // TODO: Error handling
    switch (typeSpec)
    case (is MultiTypeSpec)
    {
        value typeSpecs = typeSpec.typeSpecs.flatMap(
            (SingleTypeSpec _typeSpec)
            {
                if (parameters.defines(_typeSpec.name), !_typeSpec.parameters.empty)
                {
                    throw Exception("Multi-TypeSpec ``typeSpec`` had part ``_typeSpec`` that is considered a template parameter, but is generic.");
                }
                value result = resolveParameter<TypeSpec, Nothing>(_typeSpec.name, _typeSpec, parameters);
                switch (result)
                case (is SingleTypeSpec)
                {
                    return { result };
                }
                case (is MultiTypeSpec)
                {
                    return result.typeSpecs;
                }
                else
                {
                    throw Exception("Type failure: Got a value in type spec context.");
                }
            });
        "We know that it's one+ or bust."
        assert(nonempty seq = typeSpecs.sequence());
        return multiTypeSpec(seq);
    }
    case (is SingleTypeSpec)
    {
        value replacement = resolveParameter<TypeSpec, Nothing>(typeSpec.name, typeSpec, parameters);
        "Template parameter failure: Replacing a value in type spec context with a non-typespec value."
        assert(is TypeSpec replacement);
        return replacement;
    }
}

/// Silly name
Expression|Absent resolveParameter<Parameter, Absent = Null>(String|Absent name, Parameter|Absent original, Map<String, Expression> parameters)
        given Parameter satisfies Expression
        given Absent satisfies Null
{
    if (exists name, parameters.defines(name))
    {
        value replacement_value = parameters[name];
        if (is Parameter replacement_value)
        {
            switch (replacement_value)
            case (is SingleTypeSpec)
            {
                // Retain original parameters
                assert(is SingleTypeSpec original);
                if (!original.parameters.empty && !replacement_value.parameters.empty) {
                    throw Exception("Both replaced and original typespec define parameters. Only the original parameters will be considered.");
                }
                value spec = singleTypeSpec(
                    replacement_value.name,
                    original.parameters.collect((param) => resolveExpression<Expression, Nothing>(param, parameters)),
                    replacement_value.inPackage
                );
                return spec;
            }
            case (is Literal | SymbolName | MultiTypeSpec | FunctionCall)
            {
                return replacement_value;
            }
        }
        throw Exception();
    }

    return original;
}

// -----------------------------------------------------------------------------
//                                  TESTS
// -----------------------------------------------------------------------------

test
void resolve_template_expressions()
{
    value parameter_map_1 = HashMap
    {
        "num1"->integerLiteral(168),
        "str1"->stringLiteral("some string"),
        "name1"->stringLiteral("some_name"),
        "SomeType"->singleTypeSpec("ReallySomeType", [], packageStmt(["your", "mum"])),
        "MultiType"->multiTypeSpec([ singleTypeSpec("HollaType", [ stringLiteral("hello") ]) ])
    };

    value testCases = HashMap
    {
        field("foo", singleTypeSpec("SomeType"), valueSymbol("num1"), [], HashSet { abstractStruct })
                ->field("foo", singleTypeSpec("ReallySomeType", [], packageStmt(["your", "mum"])), integerLiteral(168), [], HashSet { abstractStruct }),
        functionCall("bar", [ singleTypeSpec("foo"), multiTypeSpec([ singleTypeSpec("hi"), singleTypeSpec("MultiType") ]) ], [ stringLiteral("hello"), valueSymbol("str1") ])
                ->functionCall("bar", [ singleTypeSpec("foo"), multiTypeSpec([ singleTypeSpec("hi"), singleTypeSpec("HollaType", [ stringLiteral("hello") ]) ]) ], [ stringLiteral("hello"), stringLiteral("some string") ])
    };

    value errors = LinkedList<[Field|FunctionCall, Field|FunctionCall, Field|FunctionCall]>();
    for (_in->_out in testCases)
    {
        value result = resolveParameterSymbols(_in, parameter_map_1);
        if (!result.equals(_out))
        {
            errors.add([_in, _out, result]);
        }
    }

    if (!errors.empty)
    {
        for (tup in errors)
        {
            value _in = tup[0];
            value _out = tup[1];
            value _result = tup[2];

            print("Field {``_in``} was not handled correctly. Expected {``_out``} but got {``_result``}.");
        }

        "Some test cases were not handled correctly. Please read the test output to find out what went wrong."
        assert (errors.empty);
    }
}

Struct structA = createStruct(
    "A",
    HashSet{abstractStruct},
    null,
    [],
    [
        field("foo", singleTypeSpec("Text"), null, []),
        field("bar", singleTypeSpec("Integer"), null, [], HashSet{abstractStruct})
    ],
    []
);

"Incorrectly implements `A`."
Struct structB = createStruct(
    "B",
    emptySet,
    singleTypeSpec("A"),
    [],
    [
        field("baz", null, null, [])
    ],
    []
);

"Correctly implements `A`."
Struct structC = createStruct(
    "C",
    emptySet,
    singleTypeSpec("A"),
    [],
    [
        field("baz", null, null, []),
        field("bar", null, null, [])
    ],
    []
);

// Cyclic inheritance
Struct structFoo = createStruct(
    "Foo",
    HashSet { abstractStruct },
    singleTypeSpec("Baz"),
    [], [], []
);

Struct structBar = createStruct(
    "Bar",
    HashSet { abstractStruct },
    singleTypeSpec("Foo"),
    [], [], []
);

Struct structBaz = createStruct(
    "Baz",
    HashSet { abstractStruct },
    singleTypeSpec("Bar"),
    [], [], []
);

// Member order
Struct structVeryTop = createStruct(
    "VeryTop",
    HashSet { abstractStruct },
    null,
    [],
    [
            field("a", null, null, []),
            field("f", null, null, [annotationUse("appended")])
    ],
    []
);

Struct structTop = createStruct(
    "Top",
    HashSet { abstractStruct },
    singleTypeSpec("VeryTop"),
    [],
    [
        field("b", null, null, []),
        field("e", null, null, [annotationUse("appended")])
    ],
    []
);

Struct structBottom = createStruct(
    "Bottom",
    emptySet,
    singleTypeSpec("Top"),
    [],
    [
        field("c", null, null, []),
        field("d", null, null, [])
    ],
    []
);

Map<SingleTypeSpec, Struct> structMap = HashMap
{
    entries = {
        structA,
        structB,
        structC,
        structFoo,
        structBar,
        structBaz,
        structVeryTop,
        structTop,
        structBottom
    }.map((struct) => singleTypeSpec(struct.name)->struct);
};

test
void concretizer_recognizes_incorrect_implementations()
{
    assertHasAssertionError(() => concretizeStruct(structB, structMap.get));
    //print(render(convertStruct(structC, structMap.get)));
    concretizeStruct(structC, structMap.get);
}

test
void concretizer_recognizes_inheritance_cycles()
{
    // Error should surface with all three
    // TODO: Create an assert on the exception type so we can be sure we didn't
    // catch something like 'Concretizing abstract struct'.
    assertHasAssertionError(() => concretizeStruct(structFoo, structMap.get));
    assertHasAssertionError(() => concretizeStruct(structBar, structMap.get));
    assertHasAssertionError(() => concretizeStruct(structBaz, structMap.get));
}

test
void concretizer_respects_member_order()
{
    value concretized = concretizeStruct(structBottom, structMap.get);
    value members = concretized.members;
    assertEquals(
        pickOfType<Field>(members)*.name,
        ('a'..'f').collect((char) => String { char })
    );
}
