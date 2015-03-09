/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    HashMap,
    LinkedList
}

import converge.entity.model.parse_ast {
    Field,
    SingleTypeSpec,
    Expression
}

import de.anhnhan.php.ast {
    Name,
    DocAnnotation,
    PHPString=StringLiteral,
    AnnotationValue,
    NamedParameter,
    phpTrue
}
import de.anhnhan.utils {
    cast,
    nullableEquality
}

Name doctrineCollection = Name(["Doctrine", "ORM", "PersistentCollection"], false);

Map<String, String> columnTypeName = HashMap
{
    "DateTime"->"datetime",
    "String"->"string",
    "Integer"->"integer",
    "Float"->"float",
    "Text"->"text",
    "ExternalReference"->"string", // We save the UID
    "UniqueId"->"string"
};

{DocAnnotation*} doctrineAnnotations(Field field)
{
    value annotations = LinkedList<DocAnnotation>();

    value typ = cast<SingleTypeSpec>(field.type);

    switch (typ?.name)
    case ("Collection")
    {
        value parameters = typ?.parameters;
        assert (is [Expression+] parameters);
        assert (is SingleTypeSpec elementType = parameters.first);

        annotations.add(DocAnnotation
                {
                    Name(["OneToMany"]);
                    NamedParameter("targetEntity", AnnotationValue(PHPString(toPHPName(elementType).render())))
                });
    }
    else
    {
        // TODO: This also specs multi-types as String. Intended behavior?
        // TODO: No support for nullable types
        if (exists columnType = columnTypeName.get(typ?.name else "String"))
        {
            annotations.add(DocAnnotation
                    {
                        Name(["Column"]);
                        {
                            NamedParameter("type", AnnotationValue(PHPString(columnType))),
                            field.unique || nullableEquality("UniqueId", typ?.name) then NamedParameter("unique", AnnotationValue(phpTrue))
                        }.coalesced;
                    });
        }
    }

    return annotations;
}
