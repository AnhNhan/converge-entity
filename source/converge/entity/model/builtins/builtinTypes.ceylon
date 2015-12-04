/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    HashSet
}

shared
Set<String> builtinTypes = HashSet
{
    "Null",
    "AutoId",
    "UniqueId",
    "String",
    "Integer",
    "Text",
    "Float",
    "Boolean",
    "DateTime",
    "Collection",
    "Map",
    "ExternalReference",
    "ExternalCollection",
    "ExternalMap"
};
