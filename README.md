# Build-Scripts

This GitHub is a collection of build scripts useful when building and testing programs and libraries on downlevel clients and clients where program updates are not freely available. It should result in working SSH, Wget, cURL and Git clients on systems like PowerMac G5, Fedora 3, CentOS 5 and Solaris 11. The scripts should mostly work on AIX, Android, BSDs, Cygwin, iOS, Linux, OS X and Solaris.

The general idea of the scripts are, you run `./build-wget.sh`, `./build-ssh.sh`, `./build-git.sh` or some other program build script to get a fresh tool. The script for the program will download and build the dependent libraries for the program. When the script completes you have a working tool in `/usr/local`.

Adding a new library script is mostly copy and paste. Start with `build-gzip.sh`, copy/paste it to a new file, and then add the necessary pieces for the library. Program scripts are copy and paste too, but they are also more involved because you have to include dependent libraries. See `build-ssh.sh` as an example because it is small. Be sure to run `./configure --help` to look for interesting options.

## Output Artifacts

All artifacts are placed in `/usr/local` by default with runtime paths and dtags set to the proper library location. The library location on 32-bit machines is `/usr/local/lib`; while 64-bit systems use `/usr/local/lib` (Debian and derivatives) or `/usr/local/lib64` (Red Hat and derivatives).

You can override the install locations with `INSTX_PREFIX` and `INSTX_LIBDIR`. `INSTX_PREFIX` is passed as `--prefix` to Autotools projects, and `INSTX_LIBDIR` is passed as `--libdir` to Autotools projects. Non-Autotools projects get patched after unpacking (see `build-bzip.sh` for an example).

The `INSTX_` prefix was chosen to avoid collisions with other shell variables. Previously, both the scripts and OpenSSL used `INSTALL_LIBDIR`, and OpenSSL installed libraries into into `/usr/local/lib/usr/local/lib/lib`.

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

Generally speaking you need some CA certificates, a modern Wget and a modern Bash. Older systems like Fedora 3 and CentOS 5 are more sensitive than newer systems, but it is OK to bootstrap a modern system  too. To install the CA certificates and modern Wget perform the following.

```
./setup-cacerts.sh

./setup-wget.sh
```

The CA certificates are written to `$HOME/.cacerts`. The CAs are public/commercial, and there are about six of them. They are used to connect to sites like `gnu.org` and `github.com`. All the script invocations that call Wget use a `--ca-certificate=<exact-ca-for-site>` option.

The bootstrapped Wget is located in `$HOME/bootstrap`. The bootstrapped version of Wget uses static linking to avoid Linux path problems. You can export the WGET variable to build the rest of the tools with `export WGET="$HOME/bootstrap/bin/wget"`.

If you are working on an antique system, like Fedora 1, then your next step is build Bash. Fedora 1 provides Bash 2.05b and it can't handle the scripts. The pain point is `[[ "$0" = "${BASH_SOURCE[0]}" ]] && exit 1 || return 1`. The command to build and use Bash in the current session is:

```
WGET="$HOME/bootstrap/bin/wget" ./build-bash.sh
...

# Use the new Bash in the current session
$ /usr/local/bin/bash
$
```

The bootstrapped Wget is anemic and you should build the full version next by running `./build-wget.sh`:

```
WGET="$HOME/bootstrap/bin/wget" ./build-wget.sh
```

You can delete `$HOME/bootstrap` at any time, but be sure you have an updated Wget that can download the source code for the remaining tools.

## Runtime Paths

The build scripts attempt to set runtime paths in everything it builds. For example, on Fedora x86_64 the  options include `-L/usr/local/lib64 -m64 -Wl,-R,/usr/local/lib64 -Wl,--enable-new-dtags`. If all goes well you will not suffer the stupid Linux path problems that have existed for the last 25 years or so.

## Dependencies

Dependent libraries are minimally tracked. Once a library is built a file with the library name is `touch`'d in `$HOME/.build-scripts`. If the file is older than 7 days then the library is automatically rebuilt. Automatic rebuilding ensures newer versions of a library are used when available and sidesteps problems with trying to track version numbers.

Programs are not tracked. When a script like `build-git.sh` or `build-ssh.sh` is run then the program is always built or rebuilt. The dependently libraries may (or may not) be built based the age as detailed in tracking, but the program is always rebuilt.

You can delete `$HOME/.build-scripts` and all dependent libraries will be rebuilt on the next run of a build script.

## Authenticity

The scripts do not check signatures on tarballs with GnuPG. Its non-trivial to build and install GnuPG for some of these machines. Instead, the scripts rely on a trusted distribution channel to deliver authentic tarballs. `setup-cacertss.sh` and `build-wget.sh` are enough to ensure the correct CAs and Wget are available to bootstrap the process with minimal risk.

It is unfortunate GNU does not run their own PKI and have their own CA. More risk could be eliminated if we only needed to trust the GNU organization and their root certificate.

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

GnuPG builds and installs OK, but it breaks Git and code signing.

GnuTLS may (or may not) build and install correctly. It is a big recipe and Guile causes a fair amount of trouble on many systems.

GMP is broken on older systems, and Nettle 3.4.1 is broken on newer systems. Programs that depend on them, like GnuTLS, will probbably be out of reach until the libraries are fixed.

If you find a bug then submit a patch or raise a bug report.
