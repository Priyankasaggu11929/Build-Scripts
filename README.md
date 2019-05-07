# Build-Scripts

This GitHub is a collection of build scripts useful for building and testing programs and libraries on downlevel clients and clients where program updates are not freely available. It should result in working SSH, Wget, cURL and Git clients on systems like PowerMac G5, Fedora 1, CentOS 5 and Solaris 11.

The general idea of the scripts are, you run `./build-wget.sh`, `./build-ssh.sh`, `./build-git.sh` or some other program build script to get a fresh tool. The script for the program will download and build the dependent libraries for the program. When the script completes you have a working tool in `/usr/local`.

## Output Artifacts

All artifacts are placed in `/usr/local` by default with runtime paths and dtags set to the proper library location. The library location on 32-bit machines is `/usr/local/lib`; while 64-bit systems use `/usr/local/lib` (Debian and derivatives) or `/usr/local/lib64` (Red Hat and derivatives).

You can override the install locations with `INSTX_PREFIX` and `INSTX_LIBDIR`. `INSTX_PREFIX` is passed as `--prefix` to Autotools projects, and `INSTX_LIBDIR` is passed as `--libdir` to Autotools projects. Non-Autotools projects get patched after unpacking (see `build-bzip.sh` for an example).

Examples of running the scripts and changing variables are shown below:

```
# Build and install using the directories described above
./build-wget.sh

# Build and install in a temp directory
INSTX_PREFIX="$HOME/tmp" ./build-wget.sh

# Build and install in a temp directory (same as the first command, but not obvious)
INSTX_PREFIX="$HOME/tmp" INSTX_LIBDIR="$INSTX_PREFIX/tmp/lib" ./build-wget.sh

# Build and install in a temp directory and use and different library path
INSTX_PREFIX="$HOME/tmp" INSTX_LIBDIR="$HOME/mylibs" ./build-wget.sh
```

The last item of interest is `INSTX_JOBS`. The variable controls the number of make jobs and is set to 4 because modern hardware is the dominant use case. Four make jobs is too much for some devices like ARM dev-boards. You can reduce the number of make jobs with:

```
INSTX_JOBS=2 ./build-curl.sh
```

## Boot strapping

Generally speaking you need some CA certificates and a modern Wget. Older systems like Fedora 1 and CentOS 5 are more sensitive than newer systems, but it is OK to bootstrap a modern system  too. To install the CA certificates and build a modern Wget perform the following.

```
./setup-cacerts.sh

./setup-wget.sh
```

The CA certificates are written to `$HOME/.cacerts`. The CAs are public/commercial issuers, and there are about eight of them. They are used to connect to sites like `gnu.org` and `github.com`. The script that call Wget usually use a `--ca-certificate=<exact-ca-for-site>` option. Sometimes the CA Zoo is used when a lot of redirects happen.

The bootstrapped Wget is located in `$HOME/bootstrap`. The bootstrapped version of Wget uses static linking to avoid Linux path problems.

If you are working on an antique system, like Fedora 1, then your next step is build Bash. Fedora 1 provides Bash 2.05b and it can't handle the scripts. The pain point is `[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1`. The command to build and use Bash in the current session is:

```
WGET="$HOME/bootstrap/bin/wget" ./build-bash.sh
...

# Use the new Bash in the current session
$ /usr/local/bin/bash
$
```

The bootstrapped Wget is anemic and you should build the full version next by running `./build-wget.sh`. After you build the full Wget you can move onto other goodies, like Git and SSH.

```
WGET="$HOME/bootstrap/bin/wget" ./build-wget.sh
```

You can delete `$HOME/bootstrap` at any time, but be sure you have an updated Wget that can download the source code for the remaining tools.

## Runtime Paths

The build scripts attempt to set runtime paths in everything it builds. For example, on Fedora x86_64 the  options include `-L/usr/local/lib64 -Wl,-R,/usr/local/lib64 -Wl,--enable-new-dtags`. `new-dtags` ensures a `RUNPATH` is used (as opposed to `RPATH`), and `RUNPATH` allows `LD_LIBRARY_PATH` overrides at runtime. The `LD_LIBRARY_PATH` support is important so self tests can run during `make check`.

If all goes well you will not suffer the stupid path problems that have plagued Linux for the last 25 years or so.

## Dependencies

Dependent libraries are minimally tracked. Once a library is built a file with the library name is `touch`'d in `$HOME/.build-scripts`. If the file is older than 7 days then the library is automatically rebuilt. Automatic rebuilding ensures newer versions of a library are used when available and sidesteps problems with trying to track version numbers.

Programs are not tracked. When a script like `build-git.sh` or `build-ssh.sh` is run then the program is always built or rebuilt. The dependently libraries may (or may not) be built based the age, but the program is always rebuilt.

You can delete `$HOME/.build-scripts` and all dependent libraries will be rebuilt on the next run of a build script.

## Authenticity

The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver authentic tarballs. `setup-cacerts.sh` and `setup-wget.sh` are enough to ensure the correct CAs and Wget are available to bootstrap the process with minimal risk.

It is unfortunate GNU does not run their own PKI and have their own CA. More risk could be eliminated if we only needed to trust the GNU organization and their root certificate.

## Boehm GC

If you are building a program that requires Boehm GC then you need to install it from the distribution. Boehm GC is trickier than other packages because the correct version of the package for a particular distro must be downloaded. C++11 and libatomics further complicates the selection process. And an additional complication is alternate stacks and signals.

On Red Hat based systems you should install `gc-devel`. On Debian based systems you should install `libgc-dev`. If a package is not available then you should manually build the garbage collector.

If you attempt a manual build then `build-boehm-gc.sh` may work for you. But the script is pinned at Boehm-GC 7.2k due to C++11 dependencies. And the manual build may not integrate well if a program uses alternate stacks and signals.

## Documentation

The scripts avoid building documentation. If you need documentation then use the package's online documentation.

Documentation is avoided for several reasons. First, the documentation adds extra dependencies, like makeinfo, html2pdf, gtk and even Perl libraries. It is not easy to satisfy some dependencies, like those on a CentOS 5, Fedora 15 or Solaris system. The older systems, CentOS 5 and Fedora 15, don't even have working repos.

Second, the documentation wastes processing time. Low-end devices like ARM dev-boards can spend their compute cycles on more important things like compiling source code. Third, the documentation wastes space. Low-end devices like ARM dev-boards need to save space on their SDcards for more important things, like programs and libraires.

Fourth, and most importantly, the documentation complicates package building. Many packages assume a maintainer is building for a desktop system with repos packed full of everything needed. And reconfiguring with `--no-docs` or `--no-gtk-doc` often requires a `bootstrap` or `autoreconf` which requires additional steps and additional dependencies.

Some documentation is built and installed. You can run `clean-docs` to remove most of it. Use `sudo` if you installed into a privileged location.

## Autotools

Autotools is its own special kind of hell. Autotools is a place where progammers get sent when they have behaved badly.

On new distros you should install Autotools from the distribution. The packages in the Autotools collection which should be installed through the distribution include:

* Aclocal
* Autoconf
* Automake
* Autopoint
* Libtool

The build scripts include `build-autotools.sh` but you should use it sparingly on old distros. Attempting to update Autotools creates a lot of tangential incompatibility problems (which is kind of sad given they have had 25 years or so to get it right).

If you install Autotools using `build-autotools.sh` and it causes more problems then it is worth, then run `clean-autotools.sh`. `clean-autotools.sh` removes all the Autotools artifacts it can find from `/usr/local`. `clean-autotools.sh` does not remove Libtool, so you may need to remove it by hand or reinstall it to ensure it is using the distro's Autotools.

## Sanitizers

One of the benefits of using the build scripts is, you can somewhat easily build programs and dependent libraries using tools like Address Sanitizer (Asan) or Undefined Behavior Sanitizer (UBsan). Only minor modifications are necessary.

First, decide on a directory to sandbox the build. As an example, `/var/sanitize`:

```
INSTX_PREFIX=/var/sanitize
```

Second, use one of the following variables to enable a sanitizer:

* `INSTX_UBSAN=1`
* `INSTX_ASAN=1`
* `INSTX_MSAN=1`

Finally, build and test the program or library as usual. For example, to build OpenSSL, perform:

```
INSTX_UBSAN=1 INSTX_PREFIX=/var/sanitize ./build-openssl.sh
```

Many programs and libraries feel it is OK to leak resources, and it screws up a lot testing. If you are using Asan or Msan and encounter too many `ERROR: LeakSanitizer: detected memory leaks`, then you may need `LSAN_OPTIONS=detect_leaks=0`. Also see [Issue 719, Suppress leak checking on exit](https://github.com/google/sanitizers/issues/719).

Once finished with testing remove `~/.build-scripts` so everything is rebuilt.

## Self Tests

The scripts attempt to run the program's or library's self tests. Usually the recipe is `make check`, but it is `make test` on occassion.

If the self tests are run and fails, then the script stops before installation. An example for GNU's Gzip is shown below.

```
==========================================
Testsuite summary for gzip 1.8
==========================================
# TOTAL: 18
# PASS:  16
# SKIP:  0
# XFAIL: 0
# FAIL:  2
# XPASS: 0
# ERROR: 0
==========================================
See tests/test-suite.log
Please report to bug-gzip@gnu.org
==========================================
make[4]: *** [test-suite.log] Error 1
make[4]: Leaving directory `/Users/scripts/gzip-1.8/tests'
...
Failed to test Gzip
```

You have three choices on self-test failure. First, you can ignore the failure, `cd` into the program's directory, and then run `sudo make install`. Second, you can fix the failure, `cd` into the program's directory, run `make`, run `make check`, and then run `sudo make install`.

Third, you can open the `build-prog.sh` script, comment the portion that runs `make check`, and then run the script again. Some libraries, like OpenSSL, use this strategy since the self tests don't work as expected on several platforms.

## Bugs

GnuPG may (or may not) build and install correctly. The libraries involved with GnuPG sometimes cannot find their prerequisites, like `libgpg-error`. GnuPG may break Git and code signing.

GnuTLS may (or may not) build and install correctly. It is a big recipe and Guile causes a fair amount of trouble on many systems.

If you find a bug then submit a patch or raise a bug report.
