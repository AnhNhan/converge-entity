/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface StructModifier
        of abstractStruct
         | uniqueField
{}

shared object abstractStruct satisfies StructModifier { string = "abstract"; }
shared object uniqueField satisfies StructModifier { string = "unique"; }

shared
interface Struct
        satisfies Node
{
    shared formal
    String name;

    shared formal
    Set<StructModifier> modifiers;

    shared formal
    SingleTypeSpec? concretizing;

    "Template parameters."
    shared formal
    DeclarationParameter[] parameters;

    shared formal
    <Field|FunctionCall>[] members;

    shared formal
    AnnotationUse[] annotations;

    shared
    Boolean abstract => modifiers.contains(abstractStruct);

    string => "Struct ``name`` concretizes ``concretizing else "none"``
               {
                   modifiers = ``modifiers``
                   parameters = ``parameters``
                   annotations = ``annotations``
                   members
                   {
               ``members*.string.map((_) => "        " + _).interpose("\n").fold("")(plus<String>)``
                   }
               }";
}

shared
Struct struct(String structName, Set<StructModifier> structModifiers, SingleTypeSpec? concretizes, DeclarationParameter[] templateParameters, <Field|FunctionCall>[] structMembers, AnnotationUse[] structAnnotations)
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
