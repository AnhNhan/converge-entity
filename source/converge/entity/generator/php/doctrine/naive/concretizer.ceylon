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
    PackageStmt,
    FunctionCall
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
    value members = LinkedList<Field|FunctionCall>();
    value appended_members = LinkedList<Field|FunctionCall>();
    value original_members = struct.members;
    value original_fields = pickOfType<Field>(struct.members);
    value parentSpec = struct.concretizing;
    if (exists parentSpec)
    {
        PackageStmt parentPackage;
        // Resolve structs indepent of type parameters
        Struct parent;
        if (exists result = resolveSpec(parentSpec, currentPackage, getParents))
        {
            parentPackage = result.key;
            parent = result.item;
        }
        else
        {
            throw Exception("Struct ``struct.name`` (package ``currentPackage.nameParts``) concretizes struct ``parentSpec.name``, which does not exist.");
        }

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

        value member_names = original_fields*.name;
        value inherited_fields = pickOfType<Field>(concretizedParent.members);
        value inherited_funcalls = pickOfType<FunctionCall>(concretizedParent.members);

        appended_members.addAll(
            inherited_fields
                    .filter(Field.appended)
                    .filter(pipe2(Field.name, not(member_names.contains)))
                    .map((field)
                    {
                        if (field.abstract)
                        {
                            throw Exception("Struct ``parent.name`` contains a
                                             field ``field.name`` that is
                                             appended, but it is abstract.
                                             Appended fields can not be abstract
                                             (as that would be pointless, since
                                             it would be overwritten by the
                                             implementation).");
                        }
                        return field;
                    })
        );
        appended_members.addAll(inherited_funcalls);

        inherited_fields
                .filter(not(Field.appended))
                // The .map operation is a simple check whether everything has been implemented
                // It simply checks whether an implementation exists, it does not
                // apply any constraints like type checking
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

    members.addAll(original_members);
    members.addAll(appended_members);

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

// Cyclic inheritance
Struct structFoo = createStruct(
    "Foo",
    emptySet,
    singleTypeSpec("Baz"),
    [], [], []
);

Struct structBar = createStruct(
    "Bar",
    emptySet,
    singleTypeSpec("Foo"),
    [], [], []
);

Struct structBaz = createStruct(
    "Baz",
    emptySet,
    singleTypeSpec("Bar"),
    [], [], []
);

Map<SingleTypeSpec, Struct> structMap = HashMap
{
    entries = {
        structA,
        structB,
        structC,
        structFoo,
        structBar,
        structBaz
    }.map((struct) => singleTypeSpec(struct.name)->struct);
};

test
void concretizer_recognizes_incorrect_implementations()
{
    assertHasAssertionError(() => concretizeStruct(structB, structMap.get));
    //print(render(convertStruct(structC, structMap.get)));
    concretizeStruct(structC, structMap.get);
}

test
void concretizer_recognizes_inheritance_cycles()
{
    // Error should surface with all three
    assertHasAssertionError(() => concretizeStruct(structFoo, structMap.get));
    assertHasAssertionError(() => concretizeStruct(structBar, structMap.get));
    assertHasAssertionError(() => concretizeStruct(structBaz, structMap.get));
}
