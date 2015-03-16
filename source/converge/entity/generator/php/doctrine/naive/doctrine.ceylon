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
    Expression,
    annotationUse
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

    value typ = cast<SingleTypeSpec>(field.type?.unnullified);

    if (annotationUse("id") in field.annotations)
    {
        annotations.add(DocAnnotation
                {
                    Name(["Id"]);
                });
    }

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
    case ("AutoId")
    {
        annotations.addAll({
            DocAnnotation
            {
                Name(["Id"]);
            },
            DocAnnotation
            {
                Name(["Column"]);
                NamedParameter("type", AnnotationValue(PHPString("integer")))
            },
            DocAnnotation
            {
                Name(["GeneratedValue"]);
                NamedParameter("strategy", AnnotationValue(PHPString("AUTO")))
            }
        });
    }
    else
    {
        // TODO: This also specs multi-types as String. Intended behavior?
        // TODO: Custom types as relationships

        function addSimpleColumnAnnotation(SingleTypeSpec? typ, String columnType)
                => annotations.add(DocAnnotation
                    {
                        Name(["Column"]);
                        {
                            NamedParameter("type", AnnotationValue(PHPString(columnType))),
                            field.unique || nullableEquality(typ?.name, "UniqueId") then NamedParameter("unique", AnnotationValue(phpTrue))
                        }.coalesced;
                    });

        if (exists typ)
        {
            if (exists columnType = columnTypeName.get(typ.name))
            {
                addSimpleColumnAnnotation(typ, columnType);
            }
            else
            {
                annotations.addAll
                {
                    DocAnnotation
                    {
                        Name(["OneToOne"]);
                        NamedParameter("targetEntity", AnnotationValue(PHPString(typ.name)))
                    }
                };
            }
        }
        else
        {
            assert (exists columnType = columnTypeName.get("String"));
            addSimpleColumnAnnotation(null, columnType);
        }
    }

    return annotations;
}
