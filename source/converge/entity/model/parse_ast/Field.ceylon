/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Field
        satisfies Node
{
    shared formal
    String name;

    shared formal
    TypeSpec? type;

    shared formal
    Expression? defaultValue;

    shared formal
    AnnotationUse[] annotations;

    shared formal
    Set<StructModifier> modifiers;

    shared
    Boolean unique => uniqueField in modifiers;

    shared
    Boolean primary => primaryField in modifiers;

    shared default
    Boolean mutable => annotationUse("mutable") in annotations;
    shared
    Boolean immutable => !mutable;

    shared default
    Boolean abstract => abstractStruct in modifiers;

    shared default
    Boolean autoInitialize => annotationUse("auto_init") in annotations;

    shared default
    Boolean appended => annotationUse("appended") in annotations;

    shared default
    Boolean reinitOnUpdate => annotationUse("reinit_on_update") in annotations;

    string => "field ``name``: ``type else "String (default)"````defaultValue exists then (" = " + (defaultValue?.string else nothing)) else ""`` ``annotations nonempty then annotations else ""``";
}

shared
Field field(String fieldName, TypeSpec? fieldType = null, Expression? fieldDefaultValue = null, AnnotationUse[] fieldAnnotations = [], Set<StructModifier>? fieldModifiers = null)
{
    object field
            satisfies Field
    {
        name = fieldName;
        type = fieldType;
        defaultValue = fieldDefaultValue;
        annotations = fieldAnnotations;
        modifiers = fieldModifiers else emptySet;
    }
    return field;
}
