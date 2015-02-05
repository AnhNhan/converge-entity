/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import anhnhan.utils {
    pipe2
}

import ceylon.collection {
    HashMap,
    HashSet
}
import ceylon.language {
    _or=or
}
import ceylon.test {
    test
}

import converge.entity.model {
    StructModifier,
    AnnotationUse,
    FunctionCall,
    field,
    integerLiteral,
    StringLiteral,
    Alias,
    singleTypeSpec,
    Expression,
    Struct,
    struct,
    stringLiteral,
    PackageStmt,
    typeAlias,
    functionCall,
    IntegerLiteral,
    SingleTypeSpec,
    Field,
    packageStmt,
    annotationUse,
    abstractStruct,
    DeclarationParameter,
    declarationParameter,
    valueSymbol,
    uniqueField,
    TypeSpec,
    multiTypeSpec,
    BooleanLiteral,
    trueLiteral,
    falseLiteral,
    NullLiteral,
    nullLiteral
}

import de.anhnhan.parser.parsec {
    ignoreSurrounding,
    zeroOrMore,
    anyOf,
    sequence,
    or,
    and,
    apply,
    satisfy,
    oneOrMore,
    separatedBy,
    literal,
    between,
    literals,
    anyLiteral,
    Error,
    Ok,
    ok,
    right,
    ParseResult,
    bindResultOk,
    leftRrightS,
    tryWhen,
    JustError,
    manySatisfy
}
import de.anhnhan.parser.parsec.string {
    whitespace,
    lowercase,
    uppercase,
    StringParser,
    StringParseResult,
    backslashEscapable,
    digit,
    keyword
}
import de.anhnhan.parser.parsec.test {
    assertCanParseWithNothingLeft,
    assertCantParse
}

StringParser<Struct|PackageStmt|Alias|FunctionCall> pTop
        = anyOf(
            pStruct,
            pAlias,
            pPackage,
            pFunctionCall
        );

StringParser typeSpecGenericStart = literal('<');
StringParser typeSpecGenericEnd = literal('>');

StringParser funcCallStart = literal('(');
StringParser funcCallEnd = literal(')');

StringParser lexScopeStart = literal('{');
StringParser lexScopeEnd = literal('}');

StringParser packageNamePartSeparator = literal('.');
StringParser typeUnionSeparator = literal('|');

StringParser annotationMarker = literal('#');

StringParser<Character[]> abstractKeyword = keyword("abstract");
StringParser<Character[]> uniqueKeyword = keyword("unique");

StringParser<SingleTypeSpec?> isSpec = tryWhen(keyword("is"), despace(pSingleTypeSpec));
StringParser<[Character+]?> nativeAsSpec = tryWhen(keyword("native_as"), despace(oneOrMore(or(identChar, literal('\\')))));

StringParser<Field|FunctionCall> pStructMember
        = or(pFunctionCall, pField);
StringParser<<Field|FunctionCall>[]> pStructMembers
        = between(lexScopeStart, despace(pStructMember), lexScopeEnd);

StringParser<Literal> despace<Literal>(StringParser<Literal> parser)
        => ignoreSurrounding<Literal, Character>(zeroOrMore(anyOf(pComment, whitespace)))(parser);

StringParser identChar = satisfy(_or(_or(Character.letter, Character.digit), (Character _) => _ in "_-$"));

StringParser<[Character+]> lIdent
        => apply(
            sequence(
                apply(lowercase, (Character _) => [_]),
                oneOrMore(identChar)
            ),
            ([[Character+]+] _) => _.rest.fold(_.first)(uncurry(Sequence<Character>.append<Character>))
        );

StringParser<[Character+]> uIdent
        => apply(
            sequence<[Character+], Character>(
                apply(uppercase, (Character _) => [_]),
                oneOrMore(identChar)
            ),
            ([[Character+]+] _) => _.rest.fold<[Character+]>(_.first)(uncurry(Sequence<Character>.append<Character>))
        );

StringParser<PackageStmt> pPackage
        = right(keyword("package"), apply(separatedBy(manySatisfy(Character.letter), packageNamePartSeparator), ([[Character+]+] parts) => packageStmt(parts.collect(`String`))));

StringParseResult<Alias> pAlias({Character*} input)
{
    value aliasKeyword = keyword("alias")(input);
    if (is Error<Anything, Character> aliasKeyword)
    {
        return aliasKeyword.toJustError;
    }
    assert (is Ok<Anything, Character> aliasKeyword);

    value ident = despace(uIdent)(aliasKeyword.rest);
    if (is Error<Anything, Character> ident)
    {
        return ident.toJustError.appendMessage("Expected: alias type identifier");
    }
    assert (is Ok<[Character+], Character> ident);
    value aliasName = String(ident.result);

    value aliasArrow = despace(literals("=>"))(ident.rest);
    if (is Error<Anything, Character> aliasArrow)
    {
        return aliasArrow.toJustError.appendMessage("Expected: =>");
    }

    value aliasTypes = separatedBy(pSingleTypeSpec, literal('|'))(aliasArrow.rest);
    if (is Error<Anything, Character> aliasTypes)
    {
        return aliasTypes.toJustError.appendMessage("Invalid TypeSpec");
    }
    assert (is Ok<[SingleTypeSpec+], Character> aliasTypes);

    return ok(typeAlias(aliasName, aliasTypes.result), aliasTypes.rest);
}

StringParseResult<Struct> pStruct({Character*} input)
{
    value abstractModifierResult = abstractKeyword(input);
    value structModifiers = HashSet<StructModifier>();
    if (is Ok<Character[], Character> abstractModifierResult)
    {
        structModifiers.add(abstractStruct);
    }

    value structKeyword = despace(keyword("struct"))(abstractModifierResult.rest);
    if (is Error<Anything, Character> structKeyword)
    {
        return JustError(abstractModifierResult.rest, ["Exptected: struct keyword"]);
    }

    value structNameResult = despace(uIdent)(structKeyword.rest);
    switch (structNameResult)
    case (is Ok<[Character+], Character>)
    {
        value structName = String(structNameResult.result);

        variable
        value rest = structNameResult.rest.skipWhile(Character.whitespace);

        DeclarationParameter[] structTemplateParameters;

        if (exists nextChar = rest.first, nextChar == '<')
        {
            value paramResult = pTypeParameterDeclaration(structNameResult.rest);
            switch (paramResult)
            case (is Ok<[DeclarationParameter+], Character>)
            {
                structTemplateParameters = paramResult.result;
                rest = paramResult.rest;
            }
            case (is Error<Anything, Character>)
            {
                return paramResult.toJustError;
            }
        }
        else
        {
            structTemplateParameters = [];
        }
        SingleTypeSpec? concretizes;
        String? nativeAs;

        if (is Ok<SingleTypeSpec?, Character> conc = despace(isSpec)(rest))
        {
            concretizes = conc.result;
            rest = conc.rest;
        }
        else
        {
            concretizes = null;
        }

        if (is Ok<[Character+]?, Character> nativ = despace(nativeAsSpec)(rest))
        {
            rest = nativ.rest;
            value result = nativ.result;
            if (exists result)
            {
                nativeAs = String(result);
            }
            else
            {
                nativeAs = null;
            }
        }
        else
        {
            nativeAs = null;
        }

        value structAnnotations = zeroOrMore(despace(pAnnotationUse))(rest);

        return pStructMembers(structAnnotations.rest).bind
        {
            (members) => ok(struct(structName, structModifiers, concretizes, structTemplateParameters, members.result, structAnnotations.result), members.rest);
            (error) => error.toJustError;
        };
    }
    case (is Error<Anything, Character>)
    {
        return structNameResult.toJustError;
    }
}

test
void testStruct()
{
    {
        "struct Foo {}",
        "abstract struct Foo {}",
        "struct Foo<val, Val> {}",
        "struct Foo { foo bar baz }",
        "struct Foo is Foo { foo bar baz }",
        "struct Foo<foo> is Bar<foo> { do_something(\"hi\") foo:Foo<123> bar }",
        "struct DiscussionTransaction is TransactionEntity<Discussion, \"DISQ\"> {}",
        "struct User is TransactionAwareEntity<UserTransaction> { username_canon #unique #normalize(lowercase, to_ascii) }"
    }.collect(assertCanParseWithNothingLeft(pStruct));

    {
        "struct foo {}",
        "struct Foo is bar {}",
        "struct Foo is Bar? {}",
        "struct Foo is Bar|Baz {}"
    }.collect(assertCantParse(pStruct));
}

StringParseResult<Field> pField({Character*} input)
{
    value abstractModifierResult = abstractKeyword(input);
    value uniqueModifierResult = despace(uniqueKeyword)(abstractModifierResult.rest);
    value fieldModifiers = HashSet<StructModifier>();
    if (is Ok<Character[], Character> abstractModifierResult)
    {
        fieldModifiers.add(abstractStruct);
    }
    if (is Ok<Anything, Character> uniqueModifierResult)
    {
        fieldModifiers.add(uniqueField);
    }

    value identResult = despace(lIdent)(uniqueModifierResult.rest);
    switch (identResult)
    case (is Ok<[Character+], Character>)
    {
        variable
        value rest = identResult.rest.skipWhile(Character.whitespace);
        TypeSpec? typeSpec;
        Expression? defaultValue;
        if (exists nextChar = rest.first, nextChar == ':')
        {
            value typeSpecResult = despace(pTypeSpec)(rest.rest);
            switch (typeSpecResult)
            case (is Ok<TypeSpec, Character>)
            {
                typeSpec = typeSpecResult.result;
                rest = typeSpecResult.rest;
            }
            case (is Error<Anything, Character>)
            {
                return typeSpecResult.toJustError.appendMessage("Invalid type specifier");
            }
        }
        else
        {
            typeSpec = null;
        }

        value defValResult = tryWhen(literal('='), despace(expr))(rest);
        switch (defValResult)
        case (is Ok<Expression?, Character>)
        {
            defaultValue = defValResult.result;
            rest = defValResult.rest;
        }
        case (is Error<Anything, Character>)
        {
            return defValResult.toJustError.appendMessage("Invalid default value");
        }

        value annotationsResult = zeroOrMore(despace(pAnnotationUse))(rest);
        return ok(field(String(identResult.result), typeSpec, defaultValue, annotationsResult.result, fieldModifiers), annotationsResult.rest);
    }
    case (is Error<Anything, Character>)
    {
        return identResult.toJustError.appendMessage("lowercase identifier");
    }
}

test
void testField()
{
    {
        "foo",
        "foo = false",
        "foo = \"bar\"",
        "foo = 123",
        "foo: Bar",
        "foo: Boolean = false",
        "foo: Null = null",
        "foo: Bar?",
        "foo: Bar|Baz",
        "foo: Bar|Baz?",
        "foo: Bar?|Baz",
        "foo: Bar?|Baz?",
        "foo:Bar<Baz<bar()>>",
        "foo:Bar<Baz<bar()>?>",
        "foo: Integer = 0 #notnull",
        "foo : Bar #bar #baz",
        "abstract foo",
        "abstract foo: Bar",
        "unique foo",
        "abstract unique foo"
    }.collect(assertCanParseWithNothingLeft(pField));

    {
        "foo:",
        "foo:t"
    }.collect(assertCantParse(pField));
}

StringParser<AnnotationUse> pAnnotationUse
        = right(annotationMarker, apply(or(pFunctionCall, lIdent), (FunctionCall|[Character+] element)
            {
                if (is FunctionCall element)
                {
                    return annotationUse(element.name, element.arguments);
                }
                else if (is [Character+] element)
                {
                    return annotationUse(String(element));
                }
                assert (false);
            }));

StringParseResult<Expression[]> optTypeParameters({Character*} input)
{
    value nextChar = typeSpecGenericStart(input);
    switch (nextChar)
    case (is Error<Character, Character>)
    {
        // No type parameters specified at all
        return ok([], input);
    }
    case (is Ok<Character, Character>)
    {
        return pTypeSpecParams(input);
    }
}

test
void testOptTypeParamaters()
{
    {
        "",
        "<foo>",
        "<foo, bar>",
        "<foo, bar()>"
    }.collect(assertCanParseWithNothingLeft(optTypeParameters));
}

test
void testOptTypeParamatersNeg()
{
    {
        "<",
        "<>",
        "<<foo>",
        "<<foo>>",
        "<foo"
    }.collect(assertCantParse(optTypeParameters));
}

StringParser<TypeSpec> pTypeSpec
        = apply(separatedBy(
            ({Character*} input)
                    => pSingleTypeSpec(input).bind
                    {
                        (single)
                        {
                            value rest = single.rest.skipWhile(Character.whitespace);
                            if (exists nextChar = rest.first, nextChar == '?')
                            {
                                return ok(multiTypeSpec([single.result, singleTypeSpec("Null", [])]), rest.rest);
                            }
                            return single;
                        };
                        identity<Error<TypeSpec, Character>>;
                    }
            ,
            despace(typeUnionSeparator)
        ),
        ([TypeSpec+] specs)
        {
            if (specs.size == 1, is SingleTypeSpec single = specs.first)
            {
                return single;
            }

            return multiTypeSpec(specs);
        });

StringParseResult<SingleTypeSpec> pSingleTypeSpec({Character*} input)
{
    value typeName = uIdent(input);
    switch (typeName)
    case (is Ok<Character[], Character>)
    {
        value name = String(typeName.result);
        value typeSpecRest = typeName.rest.skipWhile(Character.whitespace);
        return optTypeParameters(typeSpecRest).bind
        {
            (_ok) => ok(singleTypeSpec(name, _ok.result), _ok.rest);
            (error) => error.toJustError.appendMessage("Invalid type parameters");
        };
    }
    case (is Error<Character[], Character>)
    {
        return typeName.toJustError.appendMessage("Expected: type identifier");
    }
}

StringParser<[Literal+]> pExprList<Literal>(StringParser<Anything> start, StringParser<Anything> end, StringParser<Literal> expr)
        => leftRrightS(right(despace(start), separatedBy(expr, despace(literal(',')))), despace(end));

StringParser<[Expression+]> pTypeSpecParams
        = pExprList(typeSpecGenericStart, typeSpecGenericEnd, expr);
StringParser<Expression[]> pFunctionArguments
        = or(
            pExprList(literal('('), literal(')'), expr),
            apply(and(despace(funcCallStart), despace(funcCallEnd)), (Anything[] _) => [])
        );

StringParser<[DeclarationParameter+]> pTypeParameterDeclaration
        = pExprList(
            typeSpecGenericStart,
            typeSpecGenericEnd,
            ({Character*} input)
                    => oneOrMore(identChar)(input).bind
                    {
                        (ident)
                                => tryWhen(despace(literal(':')), pTypeSpec)(ident.rest).bind
                                {
                                    (typeSpec) => tryWhen(despace(literal('=')), expr)(typeSpec.rest).bind
                                    {
                                        (defaultValue) => ok(declarationParameter(String(ident.result), typeSpec.result, defaultValue.result), defaultValue.rest);
                                        (error) => error.toJustError;
                                    };
                                    (error) => error.toJustError;
                                };
                        (error) => error.toJustError;
                    }
        );

StringParseResult<FunctionCall> pFunctionCall({Character*} input, ParseResult<[Character+],Character> funNameR = lIdent(input))
        => funNameR.bind
        {
            (funNameR) => bindResultOk<FunctionCall, Expression[], Character>(
                optTypeParameters,
                (typeParamR) => pFunctionArguments(funNameR.rest).bind
                {
                    (_ok) => ok(functionCall(String(funNameR.result), typeParamR.result, _ok.result), _ok.rest);
                    (error) => error.toJustError;
                }
            )(funNameR.rest);
            (error) => error.toJustError;
        };

// TODO: Optimize with look-aheads
StringParseResult<Expression> expr({Character*} input)
        /*= anyOf(
            pInteger,
            pDoubleQuoteString,
            pSingleQuoteString,
            pBool,
            pNull,
            pFunctionCall,
            apply(lIdent, pipe2(`String`, valueSymbol)),
            pTypeSpec
        );*/
{
    value nextCharResult = anyLiteral<Character>(input);
    switch (nextCharResult)
    case (is Ok<Character, Character>)
    {
        value nextChar = nextCharResult.result;
        if (nextChar.digit)
        {
            return pInteger(input);
        }
        else if (nextChar == '"')
        {
            return pDoubleQuoteString(input);
        }
        else if (nextChar == '\'')
        {
            return pSingleQuoteString(input);
        }
        else if (nextChar.uppercase)
        {
            return pTypeSpec(input);
        }
        else
        {
            function tryLIdentAndPFun({Character*} input)
                    => lIdent(input).bind
                    {
                        (ident)
                        {
                            if (exists nextChar = input.skipWhile(Character.whitespace).first, nextChar == '(')
                            {
                                return pFunctionCall(input, ident);
                            }
                            return ok(valueSymbol(String(ident.result)), ident.rest);
                        };
                        (error) => error.toJustError;
                    };
            switch (nextChar)
            case ('n')
            {
                return or(pNull, tryLIdentAndPFun)(input);
            }
            case ('t')
            {
                return or(pBool, tryLIdentAndPFun)(input);
            }
            case ('f')
            {
                return or(pBool, tryLIdentAndPFun)(input);
            }
            else
            {
                return tryLIdentAndPFun(input);
            }
        }
    }
    case (is Error<Anything, Character>)
    {
        return nextCharResult.toJustError;
    }
}

StringParser<Character[]> pComment
        = or(
            between(literals("(*"), anyLiteral<Character>, literals("*)")),
            between(literals("/*"), anyLiteral<Character>, literals("*/"))
        );

test
void testPComment()
{
    value strs = {
        "(* cool comment, yo? *)",
        "/*********************/",
        "/**/",
        "(**)",
        "(*(**)",
        "(*hi*)"
    };
    strs.collect(assertCanParseWithNothingLeft(pComment));
}

Character stringEscapeMap(Character lit)
        => HashMap {
            't' -> '\t',
            'n' -> '\n'
        }.get(lit) else lit;

StringParser<StringLiteral> pSingleQuoteString
        = apply(backslashEscapable(literal('\''), stringEscapeMap), pipe2(`String`, stringLiteral));
StringParser<StringLiteral> pDoubleQuoteString
        = apply(backslashEscapable(literal('"'), stringEscapeMap), pipe2(`String`, stringLiteral));

StringParser<IntegerLiteral> pInteger
        = apply(oneOrMore(digit), pipe2(pipe2<Integer?, String, [[Character+]]>(`String`, parseInteger), (Integer? _) => integerLiteral(_ else nothing)));

StringParser<BooleanLiteral> pBool
        = apply(or(keyword("true"), keyword("false")), (Character[] _) => _ == "true".sequence() then trueLiteral else falseLiteral);

StringParser<NullLiteral> pNull
        = apply(keyword("null"), (Anything _) => nullLiteral);
