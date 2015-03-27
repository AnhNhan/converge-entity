/**
    Converge Entity Generator Library

    Released under Apache v2.0

    Software provided as-is, no warranty
 */

import ceylon.collection {
    HashMap
}
import ceylon.file {
    parsePath,
    File,
    lines,
    Directory,
    Path
}

import converge.entity.generator.php.doctrine.naive {
    convertStruct,
    executeFunction
}
import converge.entity.model.parse_ast {
    Struct,
    Alias,
    noPackage,
    PackageStmt,
    singleTypeSpec,
    FunctionCall
}

import de.anhnhan.parser.parsec {
    Ok,
    Error,
    parseMultipleCompletelyUsing,
    right,
    requireSuccess,
    requireSuccessP
}
import de.anhnhan.parser.parsec.string {
    StringParser,
    keyword
}
import de.anhnhan.php.ast {
    Namespace,
    Class,
    Name
}
import de.anhnhan.php.render {
    render
}
import de.anhnhan.utils {
    falsy,
    acceptEntry,
    pipe2,
    pickOfType,
    cast
}

"Run the module `converge.entity.generator`."
shared void run() {
    assert (exists command = process.arguments.first);
    value args = process.arguments.rest;

    switch (command)
    case ("test-scan")
    {
        assert (exists filePath = args.first);
        value contents = scanDir(filePath).map(
            (entry) =>
                String(entry.key.string.skip(filePath.size))
                    .trimLeading((char) => char in "/\\")
                    .replaceLast(".model", "")
                ->parse(entry.item)
        );
        print(contents);

        // TODO: More useful error message.
        "At least one file could not be fully parsed."
        assert (contents*.item.every((result) => result is Ok<Anything, Character> && result.rest.empty));
    }
    case ("test-parse")
    {
        assert (exists filePath = args.first);
        value result = parseFile(filePath);
        print(result);
    }
    case ("test-scan-and-convert")
    {
        value start = system.nanoseconds;
        assert (exists filePath = args.first);

        value startParse = system.nanoseconds;
        value processed = processAndParseFiles(scanDir(filePath));
        value endParse = system.nanoseconds;

        value startConversion = system.nanoseconds;
        // TODO: At some point include Aliases
        value structs = processed.flatMap(
            acceptEntry((PackageStmt containedPackage, [<Struct|Alias|FunctionCall>+] stuff)
                => pickOfType<Struct>(stuff).map((struct) => singleTypeSpec(struct.name, [], containedPackage)->struct)
            )
        );
        value functionCallResults = processed.flatMap(
            acceptEntry((PackageStmt pakage, [<Struct|Alias|FunctionCall>+] stuff)
                => pickOfType<FunctionCall>(stuff)
                    .flatMap((funCall) => executeFunction(funCall.name, funCall.arguments, HashMap { entries = structs; }.get, pakage))
                    .map((obj) => singleTypeSpec(cast<Struct>(obj)?.name else "was-a-class", [], pakage)->obj)
        ));
        value functionCallResultStructs = {for (entry in functionCallResults) if (is Struct struct = entry.item) entry.key->struct};
        value typeSpecMap = HashMap
        {
            entries = structs.chain(functionCallResultStructs);
        };
        function toNamespace(PackageStmt pakage, Class klass)
        {
            value parts = pakage.nameParts;
            [String+] name;
            if (nonempty parts)
            {
                name = parts;
            }
            else
            {
                name = [""];
            }

            return Namespace(Name(name), {klass});
        }
        value converted = structs.chain(functionCallResultStructs)
                .map((entry) => convertStruct(entry.item, typeSpecMap.get, entry.key.inPackage))
                .chain { for (entry in functionCallResults) if (is Class klass = entry.item) toNamespace(entry.key.inPackage, klass)}
                .collect(render)
        ;
        value endConversion = system.nanoseconds;

        print("\n\n".join(converted));
        print("\nTook (read + parse) ``(endParse - startParse) / 1_000 / 1_000.0``ms");
        print("\nTook (convert + render) ``(endConversion - startConversion) / 1_000 / 1_000.0``ms");
        print("\nTook (total) ``(system.nanoseconds - start) / 1_000 / 1_000.0``ms");
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
        print("No help written yet. ``args``");
    }
}

StringParser<[<Struct|Alias|FunctionCall>+]> parse = parseMultipleCompletelyUsing(despace(pTop));

{<Path->String>*} scanDir(String|Directory path)
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
    {<Path->String>*} files = {for (file in dir.files("*.model")) file.path->readFile(file)};

    return dir.childDirectories().flatMap(scanDir).chain(files);
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

<PackageStmt->[Struct|Alias|FunctionCall+]>[] processAndParseFiles({<Path->String>*} files)
{
    value parsePackageFile = despace(right(despace(keyword("package")), packagSpec));
    function filterPackageFiles(Path->String entry)
            => falsy(entry.key.elements.last?.equals("package.model"));

    value packageFiles = HashMap
    {
        entries = files.filter(filterPackageFiles)
                .map(acceptEntry((Path path, String contents)
                    => path.elements.exceptLast.sequence()->requireSuccess(parsePackageFile(contents)).result)
                );
    };

    value nonPackageFiles = files.filter(not(filterPackageFiles))
            .collect((Path->String entry) => (packageFiles[entry.key.elements.exceptLast.sequence()] else noPackage)->pipe2(requireSuccessP(parse), Ok<[<Struct|Alias|FunctionCall>+], Character>.result)(entry.item))
    ;

    return nonPackageFiles;
}

[Struct|Alias+] parseFile(String filePath)
{
    value contents = readFile(filePath);
    value result = parse(contents);
    if (is Error<Anything, Character> result)
    {
        print(result);
        assert (false);
    }
    assert (is Ok<[<Struct|Alias>+], Character> result);
    return result.result;
}
