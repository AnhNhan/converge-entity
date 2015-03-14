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
    convertStruct
}
import converge.entity.model.parse_ast {
    Struct,
    Alias,
    noPackage,
    PackageStmt,
    singleTypeSpec
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
import de.anhnhan.php.render {
    renderClassOrInterface
}
import de.anhnhan.utils {
    falsy,
    acceptEntry,
    pipe2,
    pickOfType
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
        assert (exists filePath = args.first);
        value processed = processAndParseFiles(scanDir(filePath));
        // TODO: At some point inlcude Aliases
        value typeSpecMap = HashMap
        {
            entries = processed.flatMap(
                acceptEntry((PackageStmt containedPackage, [<Struct|Alias>+] stuff)
                    => pickOfType<Struct>(stuff).map((struct) => singleTypeSpec(struct.name, [], containedPackage)->struct)
                )
            );
        };
        value converted = {for (pakage in processed) for (item in pakage.item) if (is Struct item) pakage.key->item}
                .map((entry) => convertStruct(entry.item, typeSpecMap.get, entry.key))
                .map(renderClassOrInterface)
        ;

        print(typeSpecMap);
        print(converted);
        print("\n\n".join(converted));
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

StringParser<[<Struct|Alias>+]> parse = parseMultipleCompletelyUsing(despace(pTop));

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

<PackageStmt->[Struct|Alias+]>[] processAndParseFiles({<Path->String>*} files)
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
            .collect((Path->String entry) => (packageFiles[entry.key.elements.exceptLast.sequence()] else noPackage)->pipe2(requireSuccessP(parse), Ok<[<Struct|Alias>+], Character>.result)(entry.item))
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
