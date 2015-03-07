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

    shared actual
    Boolean equals(Object that)
    {
        if (is AnnotationUse that)
        {
            return name==that.name &&
                arguments==that.arguments;
        }
        else
        {
            return false;
        }
    }

    shared actual
    Integer hash
    {
        variable
        value hash = 1;
        hash = 31*hash + name.hash;
        hash = 31*hash + arguments.hash;
        return hash;
    }
}

shared
AnnotationUse annotationUse(String annotationName, Expression[] annotationArguments = [])
{
    object annotationUse
            extends Object()
            satisfies AnnotationUse
    {
        name = annotationName;
        arguments = annotationArguments;
    }
    return annotationUse;
}
