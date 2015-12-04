/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import converge.entity.model.parse_ast {
    PackageStmt,
    Alias,
    Struct,
    SingleTypeSpec
}

shared
interface KeeperOfDefinitions
{
    shared formal
    void addAlias(PackageStmt packag, Alias alias_);

    shared formal
    void addStruct(PackageStmt packag, Struct struct);

    shared formal
    Map<String, Alias|Struct> symbolsFromPackacke(PackageStmt packag);

    shared formal
    {<PackageStmt->Struct|Alias>*} allSymbols;

    shared formal
    Alias|Struct? resolveTypeSpec(SingleTypeSpec typeSpec);
}
