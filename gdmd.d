/**
 * D port of dmd-script aka gdmd.
 */

module gdmd;

import std.file;
import std.path;
import std.process;
import std.regex;
import std.stdio;
import std.string;


/**
 * Encapsulates current configuration state, so that we don't have to sprinkle
 * globals around everywhere.
 */
class Config
{
    string scriptPath;  /// path to this script
    string dmdConfPath; /// path to dmd.conf
    string gdc;         /// path to GDC executable
    string gdcVersion;  /// output of gdc -dumpversion
}


/**
 * Prints command-line usage.
 */
void printUsage()
{
    writeln(q"EOF
Documentation: http://dlang.org/
               http://www.gdcproject.org/
Usage:
  gdmd files.d ... { -switch }

  files.d        D source files
  \@cmdfile      read arguments from cmdfile
  -arch ...      pass an -arch ... option to gdc
  -c             do not link
  -cov           do code coverage analysis
  -D             generate documentation
  -Dddocdir      write documentation file to docdir directory
  -Dffilename    write documentation file to filename
  -d             silently allow deprecated features
  -dw            show use of deprecated features as warnings (default)
  -de            show use of deprecated features as errors (halt compilation)
  -debug         compile in debug code
  -debug=level   compile in debug code <= level
  -debug=ident   compile in debug code identified by ident
  -debuglib=lib  debug library to use instead of phobos
  -defaultlib=lib    default library to use instead of phobos
  -deps=filename write module dependencies to filename
  -f...          pass an -f... option to gdc
  -fall-sources  for every source file, semantically process each file preceding it
  -framework ... pass a -framework ... option to gdc
  -g             add symbolic debug info
  -gc            add symbolic debug info, pretend to be C
  -gs            always emit stack frame
  -gx            add stack stomp code
  -H             generate 'header' file
  -Hdhdrdir      write 'header' file to hdrdir directory
  -Hffilename    write 'header' file to filename
  --help         print help
  -Ipath         where to look for imports
  -ignore        ignore unsupported pragmas
  -inline        do function inlining
  -Jpath         where to look for string imports
  -Llinkerflag   pass linkerflag to link
  -lib           generate library rather than object files
  -m...          pass an -m... option to gdc
  -man           open web browser on manual page
  -map           generate linker .map file
  -noboundscheck turns off array bounds checking for all functions
  -O             optimize
  -o-            do not write object file
  -odobjdir      write object files to directory objdir
  -offilename    name output file to filename
  -op            do not strip paths from source file
  -pipe          use pipes rather than intermediate files
  -profile       profile runtime performance of generated code
  -property      enforce property syntax
  -quiet         suppress unnecessary messages
  -q,arg1,...    pass arg1, arg2, etc. to to gdc
  -release       compile release version
  -run srcfile args...   run resulting program, passing args
  -unittest      compile in unit tests
  -v             verbose
  -vdmd          print commands run by this script
  -version=level compile in version code >= level
  -version=ident compile in version code identified by ident
  -vtls          list all variables going into thread local storage
  -w             enable warnings
  -wi            enable informational warnings
  -X             generate JSON file
  -Xffilename    write JSON file to filename
EOF"
    );
}

/**
 * Finds the path to this program.
 */
string findScriptPath(string argv0)
{
    // FIXME: this is not 100% reliable; we need equivalent functionality to
    // Perl's FindBin.
    return absolutePath(dirName(argv0));
}

/**
 * Finds GDC.
 */
string findGDC(string argv0)
{
    auto c = match(baseName(argv0), `^(.*-)?g?dmd(-.*)?$`).captures;
    auto targetPrefix = c[1];
    auto gdcDir = absolutePath(dirName(argv0));
    return buildNormalizedPath(gdcDir, targetPrefix ~ "gdc" ~ c[2]);
}

/**
 * Finds dmd.conf in:
 * - current working directory
 * - directory specified by the HOME environment variable
 * - directory gdmd resides in
 * - /etc directory
 */
string findDmdConf(Config cfg) {
    auto confPaths = [
        ".", environment["HOME"], cfg.scriptPath, "/etc"
    ];

    foreach (path; confPaths) {
        auto confPath = buildPath(path, "dmd.conf");
        if (exists(confPath)) {
            cfg.dmdConfPath = confPath;
            return confPath;
        }
    }
    return null;
}

/**
 * Loads environment settings from dmd.conf and stores them in the environment.
 */
void readDmdConf(Config cfg) {
    auto dmdConf = findDmdConf(cfg);
    if (dmdConf) {
        auto lines = File(dmdConf).byLine();
        int linenum = 1;

        // Look for Environment section
        typeof(match(lines.front, `.`)) m;
        while (!lines.empty && !(m = match(lines.front,
                                           `^\s*\[\s*Environment\s*\]\s*$`)))
        {
            lines.popFront();
            linenum++;
        }

        if (m) {
            lines.popFront();

            for (; !lines.empty; lines.popFront(), linenum++) {
                // Ignore comments and empty lines
                if (match(lines.front, `^(\s*;|\s*$)`))
                    continue;

                // Check for proper syntax
                m = match(lines.front, `^\s*(\S+?)\s*=\s*(.*)\s*$`);
                if (!m)
                    throw new Exception(format("Syntax error in %s line %d",
                                               dmdConf, linenum));

                string var = m.captures[1].idup;
                string val = m.captures[2].idup;

                // The special name %@P% is replaced with the path to dmd.conf
                val = replace(val, regex(`%\@P%`, "g"), cfg.dmdConfPath);

                // Names enclosed by %% are searched for in the existing
                // environment and inserted.
                val = replace!((Captures!string m) => environment[m.hit.idup])
                              (val, regex(`%(\S+?)%`, "g"));

                debug writefln("[conf] %s='%s'", var, val);
                environment[var] = val;
            }
        }
    }
}

/**
 * Initializes GDMD default configuration values, read config files, etc..
 * Returns: Config object that captures all of these settings.
 */
Config init(string[] args)
{
    auto cfg = new Config();
    cfg.scriptPath = findScriptPath(args[0]);
    cfg.gdc = findGDC(args[0]);

    readDmdConf(cfg);

    return cfg;
}

/**
 * Main program
 */
int main(string[] args)
{
    auto cfg = init(args);

    //printUsage();
    return 0;
}


// vim:set ts=4 sw=4 et: