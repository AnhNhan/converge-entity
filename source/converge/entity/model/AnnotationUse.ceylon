/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface AnnotationUse
{
    shared formal
    String name;

    "Invokation arguments."
    shared formal
    Expression[] arguments;

    string => "#``name````arguments nonempty then arguments else ""``";
}

shared
AnnotationUse annotationUse(String annotationName, Expression[] annotationArguments = [])
{
    object annotationUse
            satisfies AnnotationUse
    {
        name = annotationName;
        arguments = annotationArguments;
    }
    return annotationUse;
}
