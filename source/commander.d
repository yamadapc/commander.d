import std.algorithm : canFind, map;
import std.array : replace, split;
import std.string : strip;

class Commander {
  Option[string] options;
  string[string] params;
  bool[string] flags;

  Commander option(string flag, string description)() {
    auto option = new Option(flag, description);
    options[option.optName] = option;
    options[option.optShort] = option;
    options[option.optLong] = option;
    return this;
  }

  Commander parse(string[] args) {
    bool inParam;
    Option curOption;

    foreach(ref arg; args) {
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
        }
      }
    }

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

  unittest {
    auto program = new Commander()
      .option!("-v,--verbose", "Be verbose")
      .parse(["rdmd", "app.d", "-v"]);
    assert(program.flag("verbose") == true);
    assert(program.param("output") is null);
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

  bool hasParam() {
    return paramName !is null;
  }

  bool test(string arg) {
    return arg == optShort || arg == optLong;
  }

  static getOptName(string str) {
    return str.replace("-", "");
  }

  static isFlag(string str) {
    return str[0] == '-';
  }

  unittest {
    import pyjamas;
    Option.getOptName("-d").should.equal("d");
    Option.getOptName("--verbose").should.equal("verbose");
  }

  unittest {
    import pyjamas;
    Option.isFlag("-d").should.equal(true);
    Option.isFlag("--verbose").should.equal(true);
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
}
