/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import converge.entity.model.parse_ast {
    Struct,
    SingleTypeSpec,
    noPackage,
    PackageStmt,
    Field,
    struct,
    singleTypeSpec,
    packageStmt,
    field
}

import de.anhnhan.php.ast {
    PHPString=StringLiteral,
    Class,
    Const
}
import de.anhnhan.utils {
    pickOfType
}

Struct generateTransactionSet(
    Struct base,
    Struct? getParents(SingleTypeSpec typeSpec),
    PackageStmt currentPackage = noPackage
)
{
    // FIXME: Resolving template parameters by hand
    return struct
    {
        structName = base.name + "TransactionSet";
        structMembers = [
            field("subject", singleTypeSpec(base.name)),
            field("transactions", singleTypeSpec("Collection", [singleTypeSpec(base.name + "TransactionValue")])),
            field("previousSet", singleTypeSpec(base.name + "TransactionSet"))
        ];
        concretizes = singleTypeSpec("TransactionSet", [], packageStmt(["AnhNhan", "Converge", "Storage"]));
    };
}

Class generateTransactionValue(
    Struct base,
    Struct? getParents(SingleTypeSpec typeSpec),
    PackageStmt currentPackage = noPackage
)
{
    value transactionableFields = pickOfType<Field>(base.members)
            .filter((field)
            {
                if (field.mutable)
                {
                    return true;
                }

                if (is SingleTypeSpec type = field.type?.unnullified)
                {
                    switch (type.name)
                    case ("Collection" | "ExternalCollection" | "Map" | "ExternalMap" | "Enum")
                    {
                        return true;
                    }
                    else
                    {
                        // <nothing>
                    }
                }

                return false;
            });

    value transactionTypes = transactionableFields.flatMap(curry(transactionTypeNames)(base.name));

    value transactionValueStruct = struct
    {
        base.name + "TransactionValue";
        structModifiers = emptySet; templateParameters = []; structAnnotations = [];
        concretizes = singleTypeSpec("TransactionEntity", [], packageStmt(["AnhNhan", "Converge", "Storage"]));
        structMembers = [
            field("object", singleTypeSpec(base.name))
        ];
    };

    value klass = convertToClass(transactionValueStruct, getParents, currentPackage);

    return Class
    {
        name = klass.name;
        modifiers = klass.modifiers;
        _extends = klass._extends;
        implements = klass.implements;
        statements = klass.statements
                .chain(transactionTypes.map((type) => Const(transactionTypeConstName(type), PHPString(type))))
        ;
        annotations = klass.annotations;
        attributes = klass.attributes;
    };
}

{String*} transactionTypeNames(String baseName, Field field)
{
    value type = field.type?.unnullified;
    value rootName = baseName.lowercased;
    // TODO: Inflect field name to be singular
    value fieldName = field.name.lowercased;

    switch (type?.name)
    case ("Collection" | "ExternalCollection")
    {
        return {
            "``rootName``.add.``fieldName``",
            "``rootName``.del.``fieldName``"
        };
    }
    else
    {
        return {"``rootName``.change.``fieldName``"};
    }
}

String transactionTypeConstName(String type)
        => type.uppercased.replace(".", "_");
