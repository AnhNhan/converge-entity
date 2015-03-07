/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    HashMap
}

import converge.entity.model.parse_ast {
    Field,
    MultiTypeSpec,
    SingleTypeSpec
}

import de.anhnhan.php.ast {
    PHPExpression=Expression,
    NewObject,
    Name
}

Map<String, PHPExpression> autoInitValue = HashMap
{
    "DateTime"->NewObject(Name(["DateTime"], false))
};

PHPExpression autoInitValueFor(Field field)
{
    value type = field.type;
    if (is Null type)
    {
        throw Exception("Field ``field.name`` requires a type for auto init behavior (you don't want an empty string, no?)");
    }
    if (is MultiTypeSpec type)
    {
        throw Exception("Field ``field.name`` has a multi-type spec (type alias). We do not know how to resolve auto init values for multi-types");
    }
    assert (is SingleTypeSpec type);
    value val = autoInitValue[type.name];
    if (exists val)
    {
        return val;
    }
    else
    {
        throw Exception("Field ``field.name`` has type ``type`` for which we do not know about how to initialize it.");
    }
}
