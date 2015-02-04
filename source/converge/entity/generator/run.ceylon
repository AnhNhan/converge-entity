/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.file {
    parsePath,
    File,
    lines,
    Directory
}

import converge.entity.model {
    Alias,
    Struct,
    PackageStmt,
    FunctionCall
}

import de.anhnhan.parser.parsec {
    oneOrMore,
    Ok,
    Error
}
import de.anhnhan.parser.parsec.string {
    StringParser
}

"Run the module `converge.entity.generator`."
shared void run() {
    assert (exists command = process.arguments.first);
    value args = process.arguments.rest;

    switch (command)
    case ("test-scan")
    {
        assert (exists filePath = args.first);
        value contents = scanDir(filePath)*.item.map(parse);
        print(contents);
    }
    case ("test-parse")
    {
        assert (exists filePath = args.first);
        value result = parseFile(filePath);
        print(result);

    }
    case ("benchmark-parse")
    {
        assert (exists filePath = args.first);
        value contents = readFile(filePath);
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

StringParser<[<Struct|PackageStmt|Alias|FunctionCall>+]> parse = oneOrMore(despace(pTop));

{<String->String>*} scanDir(String|Directory path)
{
    Directory dir;

    switch (path)
    case (is Directory)
    {
        dir = path;
    }
    case (is String)
    {
        value _dir = parsePath(path).resource;
        "Provided directory does not exist."
        assert (is Directory _dir);
        dir = _dir;
    }

    variable
    {<String->String>*} files = {for (file in dir.files("*.model")) file.path.string->readFile(file)};

    return dir.childDirectories().flatMap(scanDir).sequence().chain(files);
}

String readFile(String|File path)
{
    File file;
    switch (path)
    case (is File)
    {
        file = path;
    }
    case (is String)
    {
        value _file = parsePath(path).resource;
        "Provided file does not exist."
        assert (is File _file);
        file = _file;
    }

    return lines(file).fold("")(plus<String>);
}

[Struct|PackageStmt|Alias|FunctionCall+] parseFile(String filePath)
{
    value contents = readFile(filePath);
    value result = parse(contents);
    if (is Error<Anything, Character> result)
    {
        print(result);
        assert (false);
    }
    assert (is Ok<[<Struct|PackageStmt|Alias|FunctionCall>+], Character> result);
    return result.result;
}
