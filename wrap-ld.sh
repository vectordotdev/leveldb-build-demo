#!/usr/bin/env bash

# This is a wrapper script around the system linker, which injects libgcc startup objects to allow
# statically linking Rust apps against C++ libraries while targeting musl.
#
# It should work as-is when using `cross` to cross-compile to musl. If not, it can be reconfigured
# via the environment variables shown below. Unfortunately it has to rely on a lot of hard-coded
# paths and arguments in order to do its job, so it may stop working when `cross` updates its Docker
# environment, or `rustc` changes the arguments it passes to the linker.
#
# Also see this link for compiler docs on which crt objects are used when:
# https://doc.rust-lang.org/nightly/nightly-rustc/rustc_target/spec/crt_objects/index.html

set -o errexit

# The linker to forward to. Must accept GNU LD style arguments (ie. must not be the GCC wrapper).
linker=${RUST_MUSL_LINKER:-x86_64-linux-musl-ld}

# Location of the objects to inject. These are actually libgcc objects, so use the path to that.
libgcc=${RUST_MUSL_LIBGCC:-/usr/local/lib/gcc/x86_64-linux-musl/6.4.0}

# Object to inject after the predefined crt start objects.
inject_begin=${RUST_MUSL_INJECT_BEGIN:-crtbeginS.o}

# Object to inject before the predefined crt end objects.
inject_end=${RUST_MUSL_INJECT_BEGIN:-crtendS.o}

# NB: We link the -S version of the objects because Rust produces position-independent executables.
# The non-S version fails to link in that case.

args=()
for arg in "$@"; do
    if [[ "$arg" == *"crti.o"* ]]; then
        # ctri.0 = last start object
        args+=("$arg" "$libgcc/$inject_begin")
    elif [[ "$arg" == *"crtn.o"* ]]; then
        # ctrn.0 = first end object
        args+=("$libgcc/$inject_end" "$arg")
    else
        args+=("$arg")
    fi
done

"$linker" "${args[@]}"
