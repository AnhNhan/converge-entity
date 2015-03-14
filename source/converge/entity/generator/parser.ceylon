/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

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

import converge.entity.model.parse_ast {
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
    uniqueField,
    TypeSpec,
    multiTypeSpec,
    BooleanLiteral,
    trueLiteral,
    falseLiteral,
    NullLiteral,
    nullLiteral,
    SymbolName,
    symbolName,
    ValueSymbol,
    typeSymbol,
    TypeSymbol,
    valueSymbol
}

import de.anhnhan.parser.parsec {
    ignoreSurrounding,
    zeroOrMore,
    anyOf,
    sequence,
    or,
    not,
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
    leftRrightS,
    JustError,
    left,
    lookahead,
    lookaheadCaseSingleLiteral,
    lookaheadCase,
    identityParser,
    optionalLookahead
}
import de.anhnhan.parser.parsec.string {
    whitespace,
    lowercase,
    uppercase,
    StringParser,
    StringParseResult,
    backslashEscapable,
    digit,
    keyword,
    one_or_more_chars
}
import de.anhnhan.parser.parsec.test {
    assertCanParseWithNothingLeft,
    assertCantParse
}
import de.anhnhan.utils {
    pipe2
}

StringParser<Struct|Alias> pTop
        = anyOf(
            pStruct,
            pAlias
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

StringParser<SingleTypeSpec?> isSpec = optionalLookahead(keyword("is"), despace(pSingleTypeSpec));
StringParser<[Character+]?> nativeAsSpec = optionalLookahead(keyword("native_as"), despace(oneOrMore(or(identChar, literal('\\')))));

StringParser<Field|FunctionCall> pStructMember
        = or(pFunctionCall, pField);
StringParser<<Field|FunctionCall>[]> pStructMembers
        = between(lexScopeStart, despace(pStructMember), lexScopeEnd);

StringParser<Literal> despace<Literal>(StringParser<Literal> parser)
        => ignoreSurrounding<Literal, Character>(zeroOrMore(anyOf(pComment, whitespace)))(parser);

Boolean(Character) identCharPredicate = _or(_or(Character.letter, Character.digit), (Character _) => _ in "_-$");
StringParser identChar = satisfy(identCharPredicate);
StringParser<String> identStr
        = one_or_more_chars(identChar);

StringParser<[Character+]> lIdent
        = apply(
            sequence(
                apply(lowercase, (Character _) => [_]),
                oneOrMore(identChar)
            ),
            ([[Character+]+] _) => _.rest.fold(_.first)(uncurry(Sequence<Character>.append<Character>))
        );
StringParser<String> lIdentStr
        = apply(lIdent, `String`);

StringParser<[Character+]> uIdent
        = apply(
            sequence(
                apply(uppercase, (Character _) => [_]),
                oneOrMore(identChar)
            ),
            ([[Character+]+] _) => _.rest.fold(_.first)(uncurry(Sequence<Character>.append<Character>))
        );
StringParser<String> uIdentStr
        = apply(uIdent, `String`);

StringParser<PackageStmt> packagSpec
        = apply(or(separatedBy(identStr, packageNamePartSeparator), apply(identStr, (String _) => [_])), packageStmt);

StringParser<SymbolName> nsSymbolName
        = or(
            apply(and(leftRrightS(packagSpec, despace(literals("::"))), identStr), unflatten((PackageStmt packag, String ident) => symbolName(ident, packag))),
            apply<String, Character, SymbolName>(left(identStr, not(or(literals("::"), packageNamePartSeparator))), symbolName)
        );
StringParser<ValueSymbol> pValueSymbol
        = or(
            apply(and(leftRrightS(packagSpec, despace(literals("::"))), lIdentStr), unflatten((PackageStmt packag, String ident) => valueSymbol(ident, packag))),
            apply<String, Character, ValueSymbol>(left(lIdentStr, not(or(literals("::"), packageNamePartSeparator))), valueSymbol)
        );
StringParser<TypeSymbol> pTypeSymbol
        = or(
            apply(and(leftRrightS(packagSpec, despace(literals("::"))), uIdentStr), unflatten((PackageStmt packag, String ident) => typeSymbol(ident, packag))),
            apply<String, Character, TypeSymbol>(left(uIdentStr, not(or(literals("::"), packageNamePartSeparator))), typeSymbol)
        );


test
void testSymbolName()
{
    {
        "foo",
        "Foo",
        "bar::foo",
        "bar::Foo",
        "baz.bar::foo",
        "baz.bar::Foo",
        "Bar.Baz::foo"
    }.collect(assertCanParseWithNothingLeft(nsSymbolName));

    {
        "foo.bar",
        "foo::",
        "::bar"
    }.collect(assertCantParse(nsSymbolName));
}

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

    value aliasTypes = separatedBy(pSingleTypeSpec, despace(literal('|')))(aliasArrow.rest);
    if (is Error<Anything, Character> aliasTypes)
    {
        return aliasTypes.toJustError.appendMessage("Invalid TypeSpec");
    }
    assert (is Ok<[SingleTypeSpec+], Character> aliasTypes);

    return ok(typeAlias(aliasName, aliasTypes.result), aliasTypes.rest);
}

test
void testAlias()
{
    {
        "alias Foo => Bar",
        "alias Foo => Bar | Baz",
        "alias Foo => foo.bar::Baz",
        "alias Foo => foo.bar::Baz | baz.foo::Bar"
    }.collect(assertCanParseWithNothingLeft(pAlias));
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

        value conc = despace(isSpec)(rest);
        switch (conc)
        case (is Ok<SingleTypeSpec?, Character>)
        {
            concretizes = conc.result;
            rest = conc.rest;
        }
        case (is Error<SingleTypeSpec?, Character>)
        {
            return conc.toJustError.appendMessage("Invalid type spec for parent type.");
        }

        value nativ = despace(nativeAsSpec)(rest);
        switch (nativ)
        case (is Ok<[Character+]?, Character>)
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
        case (is Error<[Character+]?, Character>)
        {
            return nativ.toJustError.appendMessage("Invalid native_as spec.");
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
        "struct Foo is bar.baz::Foo { foo bar baz }",
        "struct Foo<foo> is Bar<foo> { do_something(\"hi\") foo:Foo<123> bar }",
        "struct Foo<foo> is Bar<foo> { foo.bar::do_something(\"hi\") foo:bar.baz::Foo<123> bar }",
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

        value defValResult = optionalLookahead(literal('='), despace(expr))(rest);
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
        "foo = getSomething()",
        "foo: Bar",
        "foo: foo::Bar",
        "foo: Boolean = false",
        "foo: Null = null",
        "foo: Bar?",
        "foo: foo::Bar?",
        "foo: Bar|Baz",
        "foo: foo.baz::Bar|foo.bar::Baz",
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
                                return ok([single.result, singleTypeSpec("Null", [])], rest.rest);
                            }
                            return ok([single.result], single.rest);
                        };
                        (error) => error.toJustError;
                    }
            ,
            despace(typeUnionSeparator)
        ),
        ([[SingleTypeSpec+]+] specs)
        {
            assert (nonempty _specs = specs.flatMap(identity<[SingleTypeSpec+]>).sequence());
            if (_specs.size == 1)
            {
                return _specs.first;
            }

            return multiTypeSpec(_specs);
        });

StringParseResult<SingleTypeSpec> pSingleTypeSpec({Character*} input)
{
    value typeName = pTypeSymbol(input);
    switch (typeName)
    case (is Ok<TypeSymbol, Character>)
    {
        value symbol = typeName.result;
        value typeSpecRest = typeName.rest.skipWhile(Character.whitespace);
        return optTypeParameters(typeSpecRest).bind
        {
            (_ok) => ok(singleTypeSpec(symbol.name, _ok.result, symbol.packageSpec), _ok.rest);
            (error) => error.toJustError.appendMessage("Invalid type parameters");
        };
    }
    case (is Error<TypeSymbol, Character>)
    {
        return typeName.toJustError.appendMessage("Expected: type identifier");
    }
}

test
void testSingleTypeSpec()
{
    {
        "Foo",
        "Foo<Bar>",
        "Foo<\"baz\">",
        "bar::Foo<false, foo.baz::Bar>"
    }.collect(assertCanParseWithNothingLeft(pSingleTypeSpec));
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
            pTypeDeclarationParameter
        );

StringParser<DeclarationParameter> pTypeDeclarationParameter
        = ({Character*} input)
                    => oneOrMore(identChar)(input).bind
                    {
                        (ident)
                                => optionalLookahead(despace(literal(':')), pTypeSpec)(ident.rest).bind
                                {
                                    (typeSpec) => optionalLookahead(despace(literal('=')), expr)(typeSpec.rest).bind
                                    {
                                        (defaultValue) => ok(declarationParameter(String(ident.result), typeSpec.result, defaultValue.result), defaultValue.rest);
                                        (error) => error.toJustError;
                                    };
                                    (error) => error.toJustError;
                                };
                        (error) => error.toJustError;
                    };

StringParseResult<FunctionCall> pFunctionCall({Character*} input, ParseResult<ValueSymbol,Character> funNameR = pValueSymbol(input))
        => funNameR.bind
        {
            (funNameR) => optTypeParameters(funNameR.rest).bind
            {
                (typeParamR) =>pFunctionArguments(typeParamR.rest).bind
                {
                    (_ok) => ok(functionCall(funNameR.result.name, typeParamR.result, _ok.result, funNameR.result.packageSpec), _ok.rest);
                    (error) => error.toJustError;
                };
                (error) => error.toJustError.appendMessage("Invalid typespec for function call.");
            };
            (error) => error.toJustError.appendMessage("Expected: lident for function name.");
        };

StringParseResult<FunctionCall|ValueSymbol> pFunCallOrSymbol({Character*} input)
        => pValueSymbol(input).bind
        {
            (name) => lookahead<FunctionCall|ValueSymbol, Character>(
                lookaheadCase(despace(literal('(')), ({Character*} input) => pFunctionCall(input, name)),
                lookaheadCaseSingleLiteral((Character _) => true, identityParser(name))
            )(name.rest);
            Error<Anything, Character>.toJustError;
        };

StringParser<Expression> expr
        = lookahead(
            lookaheadCaseSingleLiteral(Character.digit, pInteger),
            lookaheadCaseSingleLiteral('"'.equals of Boolean(Character), pDoubleQuoteString),
            lookaheadCaseSingleLiteral('\''.equals of Boolean(Character), pSingleQuoteString),
            lookaheadCaseSingleLiteral(Character.uppercase, pTypeSpec),
            // pTypeSpec appears here again in case of namespaces
            lookaheadCaseSingleLiteral(Character.lowercase, anyOf(pTypeSpec, pBool, pNull, pFunCallOrSymbol))
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
        = apply(one_or_more_chars(digit), pipe2(parseInteger of Integer?(String), (Integer? _) => integerLiteral(_ else nothing)));

StringParser<BooleanLiteral> pBool
        = apply(or(keyword("true"), keyword("false")), (Character[] _) => _ == "true".sequence() then trueLiteral else falseLiteral);

StringParser<NullLiteral> pNull
        = apply(keyword("null"), (Anything _) => nullLiteral);
