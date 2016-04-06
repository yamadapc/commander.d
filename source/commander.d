import std.algorithm : canFind, map;
import std.array : replace, split;
import std.conv : to;
import std.format : format;
import std.stdio : File, stdin, writeln;
import std.regex;
import std.range : empty, popFront;
import std.string : strip;

class Commander {
  Option[] rawOptions;
  Option[string] options;
  bool[string] flags;
  string usageStr;
  string[] usageParams;
  string[string] params;
  string[] args;

  Commander option(string flag, string description)() {
    auto option = new Option(flag, description);
    options[option.optName] = option;
    options[option.optShort] = option;
    options[option.optLong] = option;
    rawOptions ~= option;
    return this;
  }

  Commander parse(string[] as) {
    bool inParam;
    Option curOption;
    auto i = 0;
    auto curUsageParams = usageParams[0..$];

    foreach(ref arg; as[1..$]) {
      if(inParam && !Option.isFlag(arg)) {
        params[curOption.paramName] = arg;
      }

      inParam = false;
      curOption = null;

      if(Option.isFlag(arg)) {
        if(arg in options) {
          auto option = options[arg];
          if(option.hasParam) {
            inParam = true;
            curOption = option;
          }

          flags[option.optName] = true;
        } else if (arg !in flags) {
          auto option = new Option(arg);
          flags[option.optName] = true;
          args ~= arg;
        }
      } else if (!curUsageParams.empty) {
        params[curUsageParams[0]] = arg;
        curUsageParams.popFront();
      } else {
        args ~= arg;
      }
    }

    return this;
  }

  Commander usage(string _usage)() {
    usageStr = _usage;
    usageParams = new Usage(_usage).parts;
    return this;
  }


  bool flag(string name) {
    if(name !in flags) {
      return false;
    }
    return flags[name];
  }

  string param(string name) {
    if(name !in params) {
      return null;
    }
    return params[name];
  }

  string help() {
    string output = "";

    if(usageStr !is null) {
      output ~= "\n  " ~ usageStr ~ "\n";
    }

    if(rawOptions.empty)
      return output ~ "\n";

    auto flagDescs = rawOptions
      .map!((o) => (o.optShort !is null ? o.optShort ~ ", ": "") ~ o.optLong);
    ulong biggestFlag = 0;
    foreach(desc; flagDescs) {
      if(desc.length > biggestFlag) {
        biggestFlag = desc.length;
      }
    }

    foreach(i, option; rawOptions) {
      auto flagDesc = flagDescs[i];
      output ~= format(
        "    %-" ~
          (biggestFlag + 2).to!string ~
          "s%s\n",
        flagDesc,
        option.description
      );
    }

    return output;
  }

  void writeHelp(File output = stdin)() {
    output.help().writeln;
  }

  unittest {
    import std.stdio;
    import pyjamas;
    auto program = new Commander()
      .usage!("Usage: command [flags] <stuff>")
      .option!("-v,--verbose", "Be verbose")
      .option!("-o, --output", "An output directory");
    program.help().should.equal("
  Usage: command [flags] <stuff>

  Options:

    -v, --verbose  Be verbose
    -o, --output   An output directory
");
  }

  unittest {
    auto program = new Commander()
      .option!("-v,--verbose", "Be verbose")
      .parse(["rdmd", "app.d", "-v"]);
    assert(program.flag("verbose") == true);
    assert(program.param("output") is null);
  }

  unittest {
    import pyjamas;
    auto program = new Commander()
      .usage!("command <here>")
      .parse(["command", "here"]);
    assert(program.flag("verbose") == false);
    assert(program.param("output") is null);
    program.param("here").should.equal("here");
  }

  unittest {
    auto program = new Commander()
      .option!("-o,--output <output-dir>", "An output directory")
      .parse(["rdmd", "app.d", "-o", "fun-directory"]);
    assert(program.flag("verbose") == false);
    assert(program.flag("output") == true);
    assert(program.param("output-dir") == "fun-directory");
  }

  unittest {
    import pyjamas;
    auto program1 = new Commander()
      .option!("-d,--data <input>", "The input")
      .option!("-o,--output <output-dir>", "An output directory")
      .option!("-v,--verbose", "Be verbose")
      .parse(["rdmd", "app.d", "-v"]);
    program1.flag("verbose").should.equal(true);
    program1.param("output").should.not.exist;
    program1.flag("output").should.equal(false);
  }

  unittest {
    import pyjamas;
    auto program2 = new Commander()
      .option!("-d,--data <input>", "The input")
      .option!("-o,--output <output-dir>", "An output directory")
      .option!("-v,--verbose", "Be verbose")
      .parse(["rdmd", "app.d", "--data", "input"]);
    program2.param("data").should.exist;
    program2.param("input").should.equal("input");
    program2.flag("data").should.equal(true);
  }
}

class Usage {
  static auto usageRegex = ctRegex!("<([^>]+)>");
  string[] parts;

  this(string usageStr) {
    foreach(part; matchAll(usageStr, usageRegex)) {
      parts ~= part[1];
    }
  }

  unittest {
    import pyjamas;
    auto usage = new Usage("command <here>");
    usage.parts.should.have.length(1);
    usage.parts.should.contain("here");
  }
}

class Option {
  string optShort = null;
  string optLong = null;
  string optName = null;
  string paramName = null;
  string description = null;
  bool paramRequired = false;
  alias required = paramRequired;

  this(string flags, string _description) {
    description = _description;
    this(flags);
  }

  this(string flags) {
    auto flagParts = flags
      .split(",")
      .map!strip;

    if(flagParts.length > 1) {
      optShort = flagParts[0];
      flagParts = flagParts[1..$];
    }

    auto longParts = flagParts[0].split(" ");
    optLong = longParts[0];
    if(longParts.length > 1) {
      paramName = longParts[1][1..$-1];
      paramRequired = longParts[1][0] == '<';
      assert(longParts[1][0] == '<' || longParts[1][0] == '[',
             "Invalid option `" ~ flags ~ "` check the parameters format");
    }

    optName = getOptName(optLong);
  }

  unittest {
    import pyjamas;
    auto opt1 = new Option("-d, --data <input>", "The input");
    opt1.test("-d").should.equal(true);
    opt1.test("--data").should.equal(true);
    opt1.paramName.should.equal("input");
    opt1.optName.should.equal("data");
    opt1.paramRequired.should.equal(true);
    opt1.hasParam.should.equal(true);
  }

  unittest {
    import pyjamas;
    auto opt2 = new Option("-v,--verbose", "Be verbose");
    opt2.test("-v").should.equal(true);
    opt2.test("--verbose").should.equal(true);
    opt2.paramName.should.equal(null);
    opt2.optName.should.equal("verbose");
    opt2.paramRequired.should.equal(false);
    opt2.hasParam.should.equal(false);
  }

  unittest {
    import pyjamas;
    auto opt2 = new Option("-v");
    opt2.optName.should.equal("v");
    opt2.paramRequired.should.equal(false);
    opt2.hasParam.should.equal(false);
  }

  bool hasParam() {
    return paramName !is null;
  }

  bool test(string arg) {
    return arg == optShort || arg == optLong;
  }

  static getOptName(string str) {
    return str.replace("-", "");
  }

  unittest {
    import pyjamas;
    Option.getOptName("-d").should.equal("d");
    Option.getOptName("--verbose").should.equal("verbose");
  }

  static isFlag(string str) {
    return str[0] == '-';
  }

  unittest {
    import pyjamas;
    Option.isFlag("-d").should.equal(true);
    Option.isFlag("--verbose").should.equal(true);
  }
}
