/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import converge.entity.model.parse_ast {
    PackageStmt,
    SingleTypeSpec,
    Struct,
    singleTypeSpec
}

<PackageStmt->Struct>? resolveSpec(SingleTypeSpec spec, PackageStmt currentPackage, Struct? retrieve(SingleTypeSpec typeSpec))
{
    if (exists result = retrieve(singleTypeSpec(spec.name, [], spec.inPackage)))
    {
        return spec.inPackage->result;
    }
    else if (exists result = retrieve(singleTypeSpec(spec.name, [], currentPackage)))
    {
        return currentPackage->result;
    }
    else
    {
        return null;
    }
}
