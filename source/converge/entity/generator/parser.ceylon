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
    RelativeSymbol,
    AnnotationUse,
    FunctionCall,
    field,
    integerLiteral,
    StringLiteral,
    Alias,
    typeSpec,
    Expression,
    Struct,
    struct,
    stringLiteral,
    PackageStmt,
    typeAlias,
    functionCall,
    IntegerLiteral,
    TypeSpec,
    Field,
    packageStmt,
    relativeSymbol,
    annotationUse,
    abstractStruct
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
    applyR,
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

StringParser<Struct|PackageStmt|Alias> pTop
        = anyOf(
            pStruct,
            pAlias,
            pPackage
        );

StringParser typeSpecGenericStart = literal('<');
StringParser typeSpecGenericEnd = literal('>');

StringParser funcCallStart = literal('(');
StringParser funcCallEnd = literal(')');

StringParser lexScopeStart = literal('{');
StringParser lexScopeEnd = literal('}');

StringParser packageNamePartSeparator = literal('.');

StringParser annotationMarker = literal('#');

StringParser<Character[]> abstractKeyword = keyword("abstract");

StringParser<TypeSpec?> isSpec = tryWhen(keyword("is"), despace(pTypeSpec));
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

    value aliasTypes = separatedBy(pTypeSpec, literal('|'))(aliasArrow.rest);
    if (is Error<Anything, Character> aliasTypes)
    {
        return aliasTypes.toJustError;
    }
    assert (is Ok<[TypeSpec+], Character> aliasTypes);

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

    // Re-using type spec, syntax is the same
    value structNameResult = despace(uIdent)(structKeyword.rest);
    switch (structNameResult)
    case (is Ok<[Character+], Character>)
    {
        value structName = String(structNameResult.result);

        variable
        value rest = structNameResult.rest.skipWhile(Character.whitespace);

        <String->TypeSpec?>[] structTemplateParameters;

        if (exists nextChar = rest.first, nextChar == '<')
        {
            value paramResult = pTypeParameterDeclaration(structNameResult.rest);
            switch (paramResult)
            case (is Ok<[<String->TypeSpec?>+], Character>)
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
        TypeSpec? concretizes;
        String? nativeAs;

        if (is Ok<TypeSpec?, Character> conc = despace(isSpec)(rest))
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
}

StringParseResult<Field> pField({Character*} input)
{
    value abstractModifierResult = abstractKeyword(input);
    value fieldModifiers = HashSet<StructModifier>();
    if (is Ok<Character[], Character> abstractModifierResult)
    {
        fieldModifiers.add(abstractStruct);
    }

    value identResult = despace(lIdent)(abstractModifierResult.rest);
    switch (identResult)
    case (is Ok<[Character+], Character>)
    {
        variable
        value rest = identResult.rest.skipWhile(Character.whitespace);
        TypeSpec? typeSpec;
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

        value annotationsResult = zeroOrMore(despace(pAnnotationUse))(rest);
        return ok(field(String(identResult.result), typeSpec, annotationsResult.result, fieldModifiers), annotationsResult.rest);
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
        "foo: Bar",
        "foo:Bar<Baz<bar()>>",
        "foo : Bar #bar #baz",
        "abstract foo",
        "abstract foo: Bar"
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
        "<foo"
    }.collect(assertCantParse(optTypeParameters));
}

StringParseResult<TypeSpec> pTypeSpec({Character*} input)
{
    value typeName = uIdent(input);
    switch (typeName)
    case (is Ok<Character[], Character>)
    {
        value name = String(typeName.result);
        value typeSpecRest = typeName.rest.skipWhile(Character.whitespace);
        return optTypeParameters(typeSpecRest).bind
        {
            (_ok) => ok(typeSpec(name, _ok.result), _ok.rest);
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

StringParser<[<String->TypeSpec?>+]> pTypeParameterDeclaration
        = pExprList(
            typeSpecGenericStart,
            typeSpecGenericEnd,
            ({Character*} input)
                    => oneOrMore(identChar)(input).bind
                    {
                        (ident)
                                => tryWhen(despace(literal(':')), pTypeSpec)(ident.rest).bind
                                {
                                    (typeSpec) => ok(String(ident.result)->typeSpec.result, typeSpec.rest);
                                    (error) => error.toJustError;
                                };
                        (error) => error.toJustError;
                    }
        );

StringParseResult<FunctionCall> pFunctionCall({Character*} input, ParseResult<[Character+],Character> funNameR = lIdent(input))
        => funNameR.bind
        {
            (funNameR) => bindResultOk<FunctionCall, Expression[], Character>(optTypeParameters, (typeParamR) => pFunctionArguments(funNameR.rest).bind
            {
                (_ok) => ok(functionCall(String(funNameR.result), typeParamR.result, _ok.result), _ok.rest);
                (error) => error.toJustError;
            })(funNameR.rest);
            (error) => error.toJustError;
        };

// TODO: Optimize with look-aheads
StringParser<Expression> expr
        = anyOf(
            pInteger,
            pDoubleQuoteString,
            pSingleQuoteString,
            pFunctionCall,
            bindResultOk<RelativeSymbol, Character[], Character>(lIdent, (ok) => applyR(ok, pipe2(`String`, relativeSymbol))),
            pTypeSpec
        );

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
