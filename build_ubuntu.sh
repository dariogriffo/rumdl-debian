rumdl_VERSION=$1
BUILD_VERSION=$2
ARCH=${3:-amd64}  # Default to amd64 if no architecture specified

if [ -z "$rumdl_VERSION" ] || [ -z "$BUILD_VERSION" ]; then
    echo "Usage: $0 <rumdl_version> <build_version> [architecture]"
    echo "Example: $0 0.2.60 1 arm64"
    echo "Example: $0 0.2.60 1 all    # Build for all architectures"
    echo "Supported architectures: amd64, arm64, all"
    exit 1
fi

# Upstream tags carry a "v" prefix (e.g. v0.2.60), and the release assets repeat
# the tag in their own name.
UPSTREAM_URL="https://github.com/rvben/rumdl/releases/download/v${rumdl_VERSION}"

# Completions are generated from the amd64 binary; they do not depend on the
# target architecture.
COMPLETIONS_RELEASE="rumdl-v${rumdl_VERSION}-x86_64-unknown-linux-musl"

# Function to map Debian architecture to the rumdl release asset name.
# Upstream publishes both a glibc (…-linux-gnu) and a musl (…-linux-musl) build
# for each architecture; we take the musl one because it is statically linked
# and therefore runs on every suite we target, bookworm included, with no libc
# dependency at all.
get_rumdl_release() {
    local arch=$1
    case "$arch" in
        "amd64") echo "rumdl-v${rumdl_VERSION}-x86_64-unknown-linux-musl" ;;
        "arm64") echo "rumdl-v${rumdl_VERSION}-aarch64-unknown-linux-musl" ;;
        *)       echo "" ;;
    esac
}

# The release tarballs contain a bare "rumdl" binary with no top-level
# directory, so they are always extracted into a directory we create.
download_release() {
    local release=$1

    rm -rf "$release" || true
    rm -f "${release}.tar.gz" || true

    if ! wget -q "${UPSTREAM_URL}/${release}.tar.gz"; then
        echo "❌ Failed to download ${release}.tar.gz"
        return 1
    fi

    mkdir -p "$release"
    if ! tar -xf "${release}.tar.gz" -C "$release"; then
        echo "❌ Failed to extract ${release}.tar.gz"
        return 1
    fi
    rm -f "${release}.tar.gz"

    if [ ! -f "$release/rumdl" ]; then
        echo "❌ Unexpected tarball layout for $release (missing rumdl binary)"
        return 1
    fi
    chmod +x "$release/rumdl"
}

# Generate the shell completions once, from the amd64 binary.
generate_completions() {
    if [ -f completions/rumdl.bash ] && [ -f completions/rumdl.fish ] && [ -f completions/_rumdl ]; then
        echo "Using existing completions/"
        return 0
    fi

    echo "Generating shell completions from ${COMPLETIONS_RELEASE}..."
    rm -rf completions || true
    mkdir -p completions

    if ! download_release "$COMPLETIONS_RELEASE"; then
        echo "❌ Failed to download ${COMPLETIONS_RELEASE} for completion generation"
        return 1
    fi

    "./${COMPLETIONS_RELEASE}/rumdl" completions bash > completions/rumdl.bash
    "./${COMPLETIONS_RELEASE}/rumdl" completions zsh  > completions/_rumdl
    "./${COMPLETIONS_RELEASE}/rumdl" completions fish > completions/rumdl.fish
    rm -rf "$COMPLETIONS_RELEASE"

    for f in completions/rumdl.bash completions/_rumdl completions/rumdl.fish; do
        if [ ! -s "$f" ]; then
            echo "❌ Completion file $f is empty"
            return 1
        fi
    done
    echo "✅ Completions generated"
}

# Function to build for a specific architecture
build_architecture() {
    local build_arch=$1
    local rumdl_release

    rumdl_release=$(get_rumdl_release "$build_arch")
    if [ -z "$rumdl_release" ]; then
        echo "❌ Unsupported architecture: $build_arch"
        echo "Supported architectures: amd64, arm64"
        return 1
    fi

    echo "Building for architecture: $build_arch using $rumdl_release"

    if ! download_release "$rumdl_release"; then
        echo "❌ Failed to prepare rumdl binary for $build_arch"
        return 1
    fi

    # Upstream ships Linux binaries for amd64/arm64 only, and the musl ones we
    # use work on every Ubuntu suite we target.
    declare -a arr=("jammy" "noble" "questing" "resolute")

    for dist in "${arr[@]}"; do
        FULL_VERSION="$rumdl_VERSION-${BUILD_VERSION}~${dist}_${build_arch}_ubu"
        echo "  Building $FULL_VERSION"

        if ! docker build . -f Dockerfile.ubu -t "rumdl-ubuntu-$dist-$build_arch" \
            --build-arg UBUNTU_DIST="$dist" \
            --build-arg rumdl_VERSION="$rumdl_VERSION" \
            --build-arg BUILD_VERSION="$BUILD_VERSION" \
            --build-arg FULL_VERSION="$FULL_VERSION" \
            --build-arg ARCH="$build_arch" \
            --build-arg RUMDL_RELEASE="$rumdl_release"; then
            echo "❌ Failed to build Docker image for $dist on $build_arch"
            return 1
        fi

        id="$(docker create "rumdl-ubuntu-$dist-$build_arch")"
        if ! docker cp "$id:/rumdl_$FULL_VERSION.deb" - > "./rumdl_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb package for $dist on $build_arch"
            return 1
        fi

        if ! tar -xf "./rumdl_$FULL_VERSION.deb"; then
            echo "❌ Failed to extract .deb contents for $dist on $build_arch"
            return 1
        fi
    done

    # Clean up extracted directory
    rm -rf "$rumdl_release" || true

    echo "✅ Successfully built for $build_arch"
    return 0
}

if ! generate_completions; then
    exit 1
fi

# Main build logic
if [ "$ARCH" = "all" ]; then
    echo "🚀 Building rumdl $rumdl_VERSION-$BUILD_VERSION for all supported architectures..."
    echo ""

    # All supported architectures
    ARCHITECTURES=("amd64" "arm64")

    for build_arch in "${ARCHITECTURES[@]}"; do
        echo "==========================================="
        echo "Building for architecture: $build_arch"
        echo "==========================================="

        if ! build_architecture "$build_arch"; then
            echo "❌ Failed to build for $build_arch"
            exit 1
        fi

        echo ""
    done

    echo "🎉 All architectures built successfully!"
    echo "Generated packages:"
    ls -la rumdl_*.deb
else
    # Build for single architecture
    if ! build_architecture "$ARCH"; then
        exit 1
    fi
fi
