commander.d
===========
Command-line interfaces in D made easy. Easy command-line parsing based in
commander.js.

## Usage
Checking for flags being parsed:
```d
auto program = new Commander()
  .option!("-v,--verbose", "Be verbose")
  .parse(["rdmd", "app.d", "-v"]);
assert(program.flag("verbose") == true);
assert(program.param("output") is null);
```

Checking for parameters being parsed
```d
auto program = new Commander()
  .option!("-o,--output <output-dir>", "An output directory")
  .parse(["rdmd", "app.d", "-o", "fun-directory"]);
assert(program.flag("verbose") == false);
assert(program.flag("output") == true);
assert(program.param("output-dir") == "fun-directory");
```


## Roadmap
- [x] Basic option parsing
- [ ] Arguments validation
- [ ] Examples
- [ ] Custom types
- [ ] Compile-time magic
- [ ] Help message generation
- [ ] Commands support

## License
This code is licensed under the MIT license for Pedro Tacla Yamada. For more
information please refer to the [LICENSE](/LICENSE) file.
