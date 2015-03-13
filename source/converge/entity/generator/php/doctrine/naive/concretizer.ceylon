/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import converge.entity.model.parse_ast {
    Struct,
    SingleTypeSpec
}

Struct concretizeStruct(Struct struct, Struct? getParents(SingleTypeSpec typeSpec))
{
    // TODO: Tmp.
    return struct;
}
