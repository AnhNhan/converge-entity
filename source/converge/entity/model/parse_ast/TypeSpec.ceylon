/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.test {
    test,
    assertTrue,
    assertFalse,
    assertEquals
}

shared
interface TypeSpec
        of MultiTypeSpec | SingleTypeSpec
        satisfies Expression
{
    "Tests whether this type-spec refers to the given type, or `Null`."
    shared
    Boolean isTypeOrNull(String type)
    {
        function check({SingleTypeSpec*} types)
                => types*.name.every(["Null", type].contains);

        value _this = this;
        switch (_this)
        case (is SingleTypeSpec)
        {
            return _this.name == type;
        }
        case (is MultiTypeSpec)
        {
            value typeSpecs = _this.typeSpecs;
            return typeSpecs.size in [1, 2] && check(typeSpecs);
        }
    }

    shared
    SingleTypeSpec? unnullified
    {
        value _this = this;
        switch (_this)
        case (is SingleTypeSpec)
        {
            return _this;
        }
        case (is MultiTypeSpec)
        {
            value typeSpecs = _this.typeSpecs;
            switch (typeSpecs.size)
            case (1|2)
            {
                return typeSpecs
                        .filter((SingleTypeSpec element) => element.name != "Null")
                        .first
                ;
            }
            else
            {
                return null;
            }
        }
    }
}

test
void nullableTypeEquality()
{
    value nullableText = multiTypeSpec([singleTypeSpec("Text"), singleTypeSpec("Null")]);
    value text1 = multiTypeSpec([singleTypeSpec("Text")]);
    value text2 = singleTypeSpec("Text");

    assertTrue(nullableText.isTypeOrNull("Text"));
    assertTrue(text1.isTypeOrNull("Text"));
    assertTrue(text2.isTypeOrNull("Text"));

    assertFalse(nullableText.isTypeOrNull("String"));
    assertFalse(text1.isTypeOrNull("String"));
    assertFalse(text2.isTypeOrNull("String"));

    /**
     * FIXME: Return what for "Null" in ["Text", "Null"]?
     *        Or in ["Null"]?
     *        Until we decided, this is going to be undefined behavior
     *        (currently returning false).
     * assertTrue(nullableText.isTypeOrNull("Null"));
     */
    assertFalse(text1.isTypeOrNull("Null"));
    assertFalse(text2.isTypeOrNull("Null"));
}

test
void test_typespec_unnullified()
{
    value nullableText = multiTypeSpec([singleTypeSpec("Text"), singleTypeSpec("Null")]);
    value text1 = multiTypeSpec([singleTypeSpec("Text")]);
    value text2 = singleTypeSpec("Text");

    assertEquals(nullableText.unnullified, text2);
    assertEquals(text1.unnullified, text2);
    assertEquals(text2.unnullified, text2);
}

"A.k.a. type unions."
shared
interface MultiTypeSpec
        satisfies TypeSpec
{
    shared formal
    [SingleTypeSpec+] typeSpecs;

    string => typeSpecs*.string.interpose("|").fold("")(plus<String>);

    shared actual
    Integer hash
    {
        variable value hash = 1;
        hash = 31*hash + typeSpecs.hash;
        return hash;
    }

    shared actual
    Boolean equals(Object that)
    {
        if (is MultiTypeSpec that)
        {
            return typeSpecs==that.typeSpecs;
        }
        else
        {
            return false;
        }
    }
}

shared
MultiTypeSpec multiTypeSpec([SingleTypeSpec+] speccedTypes)
{
    object multiTypeSpec
            extends Object()
            satisfies MultiTypeSpec
    {
        typeSpecs = speccedTypes;
    }
    return multiTypeSpec;
}

shared
interface SingleTypeSpec
        satisfies TypeSpec
{
    shared formal
    String name;

    shared formal
    PackageStmt inPackage;

    "Template parameters."
    shared formal
    Expression[] parameters;

    string => (inPackage == noPackage then "" else inPackage.nameParts.interpose(".").fold("")(plus<String>) + "::")
            + "``name````!parameters.empty then "<" + parameters*.string.interpose(", ").fold("")(plus<String>) + ">" else ""``";

    shared actual
    Boolean equals(Object that)
    {
        if (is SingleTypeSpec that)
        {
            return name==that.name &&
                inPackage==that.inPackage &&
                parameters==that.parameters;
        }
        else
        {
            return false;
        }
    }

    shared actual
    Integer hash
    {
        variable value hash = 1;
        hash = 31*hash + name.hash;
        hash = 31*hash + inPackage.hash;
        hash = 31*hash + parameters.hash;
        return hash;
    }
}

shared
SingleTypeSpec singleTypeSpec(String typeName, Expression[] typeParameters = [], PackageStmt packag = noPackage)
{
    object typeSpec
            extends Object()
            satisfies SingleTypeSpec
    {
        name = typeName;
        parameters = typeParameters;
        inPackage = packag;
    }
    return typeSpec;
}

shared
SingleTypeSpec parameterlessSingleTypeSpec(SingleTypeSpec typeSpec)
        => singleTypeSpec(typeSpec.name, [], typeSpec.inPackage);

shared
SingleTypeSpec repackageSingleTypeSpec(SingleTypeSpec typeSpec, PackageStmt pakage = noPackage, Boolean clearParams = false)
        => singleTypeSpec(typeSpec.name, clearParams then [] else typeSpec.parameters, pakage);
