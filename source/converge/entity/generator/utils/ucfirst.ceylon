/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

shared
String ucfirst(String input)
        => String({input.first?.uppercased, *input.rest}.coalesced);
