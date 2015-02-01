/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.file {
    parsePath,
    File,
    lines
}

import converge.entity.model {
    Alias,
    Struct,
    PackageStmt
}

import de.anhnhan.parser.parsec {
    oneOrMore,
    Ok,
    Error
}

"Run the module `converge.entity.generator`."
shared void run() {
    assert (exists command = process.arguments.first);
    value args = process.arguments.rest;

    switch (command)
    case ("test-parse")
    {
        assert (exists filePath = args.first);
        value file = parsePath(filePath).resource;
        "Provided file does not exist."
        assert (is File file);

        value contents = lines(file).fold("")(plus<String>);
        value parse = oneOrMore(despace(pTop));

        value result = parse(contents);
        if (is Error<Anything, Character> result)
        {
            print(result);
            return;
        }
        assert (is Ok<[<Struct|PackageStmt|Alias>+], Character> result);
        print(result.result);

        value start = system.nanoseconds;
        for (_ in 0..1_000)
        {
            parse(contents);
        }
        print("\nTook ``(system.nanoseconds - start) / 1_000 / 1_000.0``ms");
    }
    else
    {
        print("No help written yet.");
    }
}
