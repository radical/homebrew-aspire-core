class Aspire < Formula
  desc "CLI for building observable, production-ready distributed applications"
  homepage "https://aspire.dev/"
  url "https://github.com/radical/aspire/archive/3be8b8767be8aab2fa74f776fdab2220b6ea79be.tar.gz"
  version "0.0.0-3be8b87"
  sha256 "47c4a90e767f067347153e4c6f7e990b9fce43c51a74bace9b6e5849cb1008af"
  license "MIT"
  head "https://github.com/microsoft/aspire.git", branch: "main"

  # livecheck drives version-discovery telemetry; useful for maintainers and
  # dashboards even when autobump is disabled.
  livecheck do
    url :stable
    strategy :github_latest
  end

  # We bump this formula from our release pipeline (per-RID SDK resources are
  # not autobumpable in lockstep). Suppress BrewTestBot's autobump so it doesn't
  # open competing PRs with stale resource SHAs.

  # NativeAOT publish requires clang on Linux. macOS gets the linker from Xcode CLT.
  uses_from_macos "zlib"
  on_linux do
    depends_on "llvm" => :build
  end

  # Vendored .NET SDK, pinned to 10.0.201 (sourced from the release tag's
  # global.json). URLs and SHA256s are resolved per release against dotnet's
  # release metadata and substituted into the placeholders below.
  #
  # We vendor because homebrew-core's `dotnet` formula tracks the 1xx feature
  # band only (livecheck regex `/^v?(\d+\.\d+\.1\d\d)$/i`); we develop and test
  # against the SDK version pinned in global.json (currently 2xx band). Shipping
  # a binary built against a different SDK than upstream tests would be a real
  # correctness risk for production releases.
  #
  # A single resource with per-platform url/sha256 (the homebrew-core idiom,
  # e.g. crystal.rb's `boot` resource) means brew fetches only the current
  # platform's SDK (~230 MB) rather than all four RIDs (~950 MB), which is what
  # separate top-level resource blocks would force since brew downloads every
  # declared resource before `install` runs.
  resource "dotnet-sdk" do
    on_macos do
      on_arm do
        url "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.201/dotnet-sdk-10.0.201-osx-arm64.tar.gz"
        sha256 "f1f3faf1380f88af6e5854d8153c63e188b9b2407643df0f9c5ff52e5768722c"
      end
      on_intel do
        url "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.201/dotnet-sdk-10.0.201-osx-x64.tar.gz"
        sha256 "87b42341bcbdfc147ae7c81fb2279b91a0c95678cbfc1cb03732d124759a8cfd"
      end
    end
    on_linux do
      on_arm do
        url "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.201/dotnet-sdk-10.0.201-linux-arm64.tar.gz"
        sha256 "d46273b9514a13271dd7b668758622bfb335e7630911631322c42289e84d3962"
      end
      on_intel do
        url "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.201/dotnet-sdk-10.0.201-linux-x64.tar.gz"
        sha256 "ac6b0ea9aae5d96ee5c41fed1d11c1d5c6bf8d994c75389da8055bea23e44eef"
      end
    end
  end

  def install
    arch = Hardware::CPU.arm? ? "arm64" : "x64"
    os   = OS.mac? ? "osx" : "linux"
    rid  = "#{os}-#{arch}"

    # Stage the vendored SDK into the buildpath so the build runs from a known
    # toolset. `resource(...).stage` is the only step that must stay in Ruby
    # (it's Homebrew DSL); everything else is delegated below. The `dotnet-sdk`
    # resource resolves to the current platform's SDK via its on_macos/on_linux
    # + on_arm/on_intel guards.
    resource("dotnet-sdk").stage do
      (buildpath/"dotnet-sdk").install Dir["./*"]
    end

    # Build + lay out the keg. All imperative install logic lives in the repo
    # script so that layout changes ride along with the source tarball and are
    # validated by .github/workflows/homebrew-formula.yml. The homebrew-core
    # formula only ever bumps url/sha256/version and the resource SHAs — never
    # this block — so new releases keep working without a formula edit.
    system "eng/homebrew-core/install-formula.sh",
           "--rid", rid,
           "--dotnet-root", buildpath/"dotnet-sdk",
           "--libexec", libexec,
           "--bin", bin,
           "--version", version.to_s
  end

  test do
    # Real-shape smoke. `--version` alone wouldn't catch a missing bundle
    # layout; `aspire new aspire-empty` exercises template extraction
    # plus the bundle being discoverable via LayoutDiscovery.
    assert_match version.to_s, shell_output("#{bin}/aspire --version")

    # Sanity: the canonical sidecar-route layout anchor resolves through
    # libexec/bundle/ → versions/<v>/{managed,dcp}. If this fails the
    # CLI runs but every polyglot command would error at first use.
    assert_path_exists libexec/"bundle/managed"
    assert_path_exists libexec/"bundle/dcp"

    ENV["DOTNET_CLI_TELEMETRY_OPTOUT"] = "1"
    ENV["DOTNET_NOLOGO"] = "1"

    # The flags are load-bearing in brew test's non-interactive sandbox:
    #   --language csharp           skips the language-selection prompt
    #   --non-interactive           disables all prompts and spinners
    #   --suppress-agent-init       skips the agent-skill install prompt
    # Without them the command aborts with "Cannot show selection prompt
    # since the current terminal isn't interactive."
    system bin/"aspire", "new", "aspire-empty",
           "--language", "csharp",
           "--non-interactive",
           "--suppress-agent-init",
           "--nologo",
           "-o", testpath/"smoke",
           "-n", "SmokeTest"
    assert_path_exists testpath/"smoke/apphost.cs"
  end
end
