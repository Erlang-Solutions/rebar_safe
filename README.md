# SAFE - Security Analysis For Erlang
<br>
<picture style="margin-right: 15px; float: left;">
  <source
    media="(prefers-color-scheme: dark)"
    srcset="https://security-audit-logo.s3.eu-central-1.amazonaws.com/image_safe_logo_dark.png"
    width="170px"
    align="left"
  />
  <source
    media="(prefers-color-scheme: light)"
    srcset="https://security-audit-logo.s3.eu-central-1.amazonaws.com/image_safe_logo_light.png"
    width="170px"
    align="left"
  />
  <img
    src="https://security-audit-logo.s3.eu-central-1.amazonaws.com/image_safe_logo_light.png"
    alt="Security Audit For Erlang and Elixir"
    width="170px"
    align="left"
  />
</picture>

A rebar3 plugin that wires [SAFE](https://safe-docs.erlang-solutions.com/)
— Erlang/Elixir security scanner from Erlang Solutions — directly
into your build, so you can run a security check with `rebar3 safe analyse` 
and get results in your terminal.

The plugin takes care of everything: downloads the right version of SAFE
for your machine (with SHA256 verification of course), inspects your project 
structure to build a config, and then hands off to SAFE for the actual analysis. 

## Features 

- A `rebar3 safe` command with `fingerprint`, `analyse`, `download`,
  `version`, and `help` subcommands.
- Automatic binary download and SHA256 checksum verification.
- Project inspection that handles plain apps and umbrella projects.
- Fully offline after the first download — SAFE runs locally and does
  not phone home with your source.

## Installation

Add the plugin to your project's `rebar.config`:

```erlang
{plugins, [
  {rebar_safe, "1.0.1"}
]}.
```

The first time you invoke `rebar3 safe <task>` the plugin
will fetch the SAFE binary into `_build/safe/` and cache it there.

## Usage

There are two phases. First, fingerprint your project — this generates a
unique, anonymous fingerprint that we (Erlang Solutions) use to issue a
license. Your code never leaves your machine; the fingerprint contains
only structural metadata about your apps and build paths.

```bash
rebar3 safe fingerprint
```

> **SAFE is free for open-source projects.** If you maintain one, please
> reach out at <safe@erlang-solutions.com> and we'll sort out a license.

Once you have a license and it's exported into your environment (see the
[SAFE docs](https://safe-docs.erlang-solutions.com/) for the variable
name and format), run the analysis:

```bash
rebar3 safe analyse
```

The analysis exits non-zero if vulnerabilities are found, so it integrates
cleanly with common CI providers.

### Other tasks

```bash
rebar3 safe download    # Just fetch the binary, don't run anything
rebar3 safe version     # Print plugin and SAFE binary versions
rebar3 safe help        # Show the full task list
```

Set `DEBUG=1` to get verbose output about paths, version resolution, and
the exact command being passed to SAFE — useful when something isn't
behaving and you want to see what the plugin thinks it's doing.




## Development

```bash
rebar3 compile           # Build the plugin
rebar3 eunit             # Unit tests
rebar3 dialyzer          # Type analysis
rebar3 fmt --check       # Formatting

python3 scripts/integration_test.py -v   # End-to-end tests against fixtures
```

The integration tests symlink the local plugin into the `fixtures/`
projects via `_checkouts`, run the real `rebar3 safe` commands, and
assert against the output. They need a network connection on first run
to fetch the SAFE binary; after that they work offline.

### Requirements

- **Erlang/OTP:** 25 or later (CI tests 25, 26, 27, 28)
- **rebar3:** 3.18 or later (CI uses 3.24)
- **OS:** Linux or macOS, x86_64

## Security

The plugin verifies SHA256 checksums on every binary download and uses
TLS with the `certifi` CA bundle for all network operations. 

## License

Apache 2.0 — see [LICENSE](LICENSE).
