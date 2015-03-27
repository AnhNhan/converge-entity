/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    HashMap
}
import ceylon.language.meta {
    type
}

import converge.entity.model.parse_ast {
    SingleTypeSpec,
    noPackage,
    PackageStmt,
    Struct,
    Expression
}

import de.anhnhan.php.ast {
    Class
}

"TODO: Function signature will change.

 Currently only usable for top-level functions. Only supports
 `generateTransactionSet` and `generateTransactionValue`."
shared
{Class|Struct*} executeFunction(
    String functionName,
    Expression[] args,
    Struct? getParents(SingleTypeSpec typeSpec),
    PackageStmt currentPackage = noPackage
)
{
    // TODO: Better error handling. More debug info.

    value functionMap = HashMap
    {
        "generateTransactionSet"->
                ((SingleTypeSpec spec)
                {
                    if (exists struct = resolveSpec(spec, currentPackage, getParents)?.item)
                    {
                        return {generateTransactionSet(struct, getParents, currentPackage)};
                    }

                    throw Exception("``functionName``: Type spec ``spec`` refers to an non-existing struct.");
                }),
        "generateTransactionValue"->
                ((SingleTypeSpec spec)
                {
                    if (exists struct = resolveSpec(spec, currentPackage, getParents)?.item)
                    {
                        return {generateTransactionValue(struct, getParents, currentPackage)};
                    }

                    throw Exception("``functionName``: Type spec ``spec`` refers to an non-existing struct.");
                })
    };

    value selectedFunction = functionMap.get(functionName);
    if (is Null selectedFunction)
    {
        throw Exception("Function ``functionName`` does not exist. Note that function names are case-sensitive.");
    }
    "Waiting for 1.2"
    assert (exists selectedFunction);

    // FIXME: Hard-coded for type-spec params. Once we introduce other functions, we should change this.

    if (args.size != 1)
    {
        throw Exception("Function ``functionName`` only accepts a single arguments.");
    }
    assert (nonempty args);

    SingleTypeSpec typeSpec;
    if (is SingleTypeSpec _typeSpec = args.first)
    {
        typeSpec = _typeSpec;
    }
    else
    {
        throw Exception("``functionName``: Expected single type spec, not ``args.first`` (``type(args.first)``)");
    }

    return selectedFunction(typeSpec);
}
