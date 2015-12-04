/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
interface Constraint
{}

shared
interface IsOf
        of isValue | isType
{}

shared object isValue satisfies IsOf {}
shared object isType satisfies IsOf {}

shared
interface ValueOfType
{}

shared
interface TypeOfType
{}

shared
interface Wildcard
        of valueWildcard | typeWildcard
{}

shared object valueWildcard satisfies Wildcard {}
shared object typeWildcard satisfies Wildcard {}
