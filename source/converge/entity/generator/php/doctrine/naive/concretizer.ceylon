/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    LinkedList
}

import converge.entity.model.parse_ast {
    createStruct=struct,
    Struct,
    SingleTypeSpec,
    Field
}

import de.anhnhan.utils {
    pickOfType,
    pipe2
}

Struct concretizeStruct(Struct struct, Struct? getParents(SingleTypeSpec typeSpec), String[] concretizationHierarchy = [])
{
    value members = LinkedList(pickOfType<Field>(struct.members));
    value parentSpec = struct.concretizing;
    if (exists parentSpec)
    {
        value parent = getParents(parentSpec);
        switch (parent)
        case (is Null)
        {
            throw Exception("Struct ``struct.name`` concretizes struct ``parentSpec.name``, which does not exist.");
        }
        case (is Struct)
        {
            // Prevent inheritance cycles, which will cause an infinite loop
            // O(n) space, O(n²) time. Well, n is usually small enough (does anybody get over 5 in userland projects?)
            if (parent.name in concretizationHierarchy)
            {
                assert (nonempty concretizationHierarchy);
                throw ConcretizationCycle(struct, concretizationHierarchy);
            }

            value concretizedParent = concretizeStruct(parent, getParents, concretizationHierarchy.append([struct.name]));
            if (!concretizedParent.abstract)
            {
                throw Exception("Struct ``struct.name`` concretizes struct ``concretizedParent.name``, which is not abstract.");
            }

            value member_names = members*.name;
            pickOfType<Field>(concretizedParent.members)
                    // The .map operation is a simple check whether everything has been implemented
                    .map((field)
                        {
                            if (field.abstract, !member_names.contains(field.name))
                            {
                                throw Exception("Struct ``struct.name`` concretizes "
                                    + "struct ``parent.name``, which declares an abstract "
                                    + "field ``field`` that is not implemented in the "
                                    + "concretizing struct.");
                            }
                            return field;
                        })
                    .filter(pipe2(Field.name, not(member_names.contains)))
                    .collect(members.push)
            ;
        }
    }

    return createStruct
    {
        struct.name;
        struct.modifiers;
        struct.concretizing;
        struct.parameters;
        members.sequence();
        struct.annotations;
    };
}

shared
class ConcretizationCycle(
    shared
    Struct struct,
    shared
    [String+] hierarchy
)
        extends Exception("Struct ``struct.name`` concretizes struct ``struct.concretizing?.name else nothing``, which created a cyclic hierarchy. (``hierarchy``)")
{}
