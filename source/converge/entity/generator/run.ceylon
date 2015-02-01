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

import de.anhnhan.parser.parsec {
    oneOrMore
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
        print(result);

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
