/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface StructModifier
        of abstractStruct
{}

shared object abstractStruct satisfies StructModifier {}

shared
interface Struct
{
    shared formal
    String name;

    shared formal
    Set<StructModifier> modifiers;

    shared formal
    TypeSpec? concretizing;

    "Template parameters."
    shared formal
    <String->TypeSpec?>[] parameters;

    shared formal
    <Field|FunctionCall>[] members;

    shared formal
    AnnotationUse[] annotations;
}

shared
Struct struct(String structName, Set<StructModifier> structModifiers, TypeSpec? concretizes, <String->TypeSpec?>[] templateParameters, <Field|FunctionCall>[] structMembers, AnnotationUse[] structAnnotations)
{
    object struct
            satisfies Struct
    {
        name = structName;
        modifiers = structModifiers;
        concretizing = concretizes;
        parameters = templateParameters;
        members = structMembers;
        annotations = structAnnotations;
    }
    return struct;
}
