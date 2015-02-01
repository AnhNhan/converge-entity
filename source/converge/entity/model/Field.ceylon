/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Field
{
    shared formal
    String name;

    shared formal
    TypeSpec? type;

    shared formal
    AnnotationUse[] annotations;

    shared formal
    Set<StructModifier> modifiers;
}

shared
Field field(String fieldName, TypeSpec? fieldType, AnnotationUse[] fieldAnnotations, Set<StructModifier>? fieldModifiers = null)
{
    object field
            satisfies Field
    {
        name = fieldName;
        type = fieldType;
        annotations = fieldAnnotations;
        modifiers = fieldModifiers else emptySet;
    }
    return field;
}
