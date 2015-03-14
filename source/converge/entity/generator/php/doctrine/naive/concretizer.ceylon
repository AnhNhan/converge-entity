/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    LinkedList,
    HashSet,
    HashMap
}
import ceylon.test {
    test
}

import converge.entity.model.parse_ast {
    createStruct=struct,
    Struct,
    SingleTypeSpec,
    Field,
    abstractStruct,
    field,
    singleTypeSpec,
    noPackage,
    PackageStmt
}

import de.anhnhan.utils {
    pickOfType,
    pipe2,
    assertHasAssertionError
}

Struct concretizeStruct(
    Struct struct,
    Struct? getParents(SingleTypeSpec typeSpec),
    PackageStmt currentPackage = noPackage,
    String[] concretizationHierarchy = []
)
{
    value members = LinkedList(pickOfType<Field>(struct.members));
    value parentSpec = struct.concretizing;
    if (exists parentSpec)
    {
        // Resolve structs indepent of type parameters
        value parent = getParents(singleTypeSpec(parentSpec.name, [], parentSpec.inPackage))
                            else getParents(singleTypeSpec(parentSpec.name, [], currentPackage))
        ;
        switch (parent)
        case (is Null)
        {
            throw Exception("Struct ``struct.name`` (package ``currentPackage.nameParts``) concretizes struct ``parentSpec.name``, which does not exist.");
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

            value concretizedParent = concretizeStruct(parent, getParents, parentSpec.inPackage, concretizationHierarchy.append([struct.name]));
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

// -----------------------------------------------------------------------------
//                                  TESTS
// -----------------------------------------------------------------------------

Struct structA = createStruct(
    "A",
    HashSet{abstractStruct},
    null,
    [],
    [
        field("foo", singleTypeSpec("Text"), null, []),
        field("bar", singleTypeSpec("Integer"), null, [], HashSet{abstractStruct})
    ],
    []
);

"Incorrectly implements `A`."
Struct structB = createStruct(
    "B",
    emptySet,
    singleTypeSpec("A"),
    [],
    [
        field("baz", null, null, [])
    ],
    []
);

"Correctly implements `A`."
Struct structC = createStruct(
    "C",
    emptySet,
    singleTypeSpec("A"),
    [],
    [
        field("baz", null, null, []),
        field("bar", null, null, [])
    ],
    []
);

Map<SingleTypeSpec, Struct> structMap = HashMap
{
    entries = {structA, structB, structB}.map((struct) => singleTypeSpec(struct.name)->struct);
};

test
void concretizer_recognizes_inheritance_cycles()
{
    assertHasAssertionError(() => concretizeStruct(structB, structMap.get));
    //print(render(convertStruct(structC, structMap.get)));
    concretizeStruct(structC, structMap.get);
}
