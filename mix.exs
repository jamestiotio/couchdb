defmodule CoverTool do
  def start(path, options) do
    {dirs, options} = Keyword.pop(options, :dirs, [])
    fun = ExCoveralls.start(path, options)
    Mix.shell().info("Cover compiling modules ...")
    :cover.stop()
    :cover.start()

    Enum.each(dirs, fn path ->
      path
      |> Path.expand(__DIR__)
      |> String.to_charlist()
      |> :cover.compile_beam_directory()
    end)

    ExCoveralls.ConfServer.start()
    ExCoveralls.ConfServer.set(options)
    ExCoveralls.StatServer.start()
    fun
  end
end

defmodule Mix.Tasks.Suite do
  @moduledoc """
  Helper task to create `suites.elixir` file. It suppose to be used as follows
  ```
  MIX_ENV=integration mix suite > test/elixir/test/config/suite.elixir
  ```
  """
  use Mix.Task
  @shortdoc "Outputs all available integration tests"
  def run(_) do
    Path.wildcard(Path.join(Mix.Project.build_path(), "/**/ebin"))
    |> Enum.filter(&File.dir?/1)
    |> Enum.map(&Code.append_path/1)

    tests =
      Couch.Test.Suite.list()
      |> Enum.sort()
      |> Couch.Test.Suite.group_by()

    IO.puts(Couch.Test.Suite.pretty_print(tests))
  end
end

defmodule CouchDBTest.Mixfile do
  use Mix.Project

  def project do
    [
      app: :couchdbtest,
      version: "0.1.0",
      elixir: "~> 1.13",
      lockfile: Path.expand("mix.lock", __DIR__),
      deps_path: Path.expand("src", __DIR__),
      build_path: Path.expand("_build", __DIR__),
      compilers: [:elixir, :app],
      start_permanent: Mix.env() == :prod,
      build_embedded: Mix.env() == :prod,
      deps: deps(),
      consolidate_protocols: Mix.env() not in [:test, :dev, :integration],
      test_paths: get_test_paths(Mix.env()),
      elixirc_paths: elixirc_paths(Mix.env()),
      prune_code_paths: false,
      test_coverage: [
        tool: CoverTool,
        dirs: get_coverage_paths(),
        type: "html"
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      applications: [:httpotion]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/elixir/lib", "test/elixir/test/support"]
  defp elixirc_paths(:integration), do: ["test/elixir/lib", "test/elixir/test/support"]
  defp elixirc_paths(_), do: ["test/elixir/lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps() do
    deps_list = [
      {:junit_formatter, "~> 3.0", only: [:dev, :test, :integration]},
      {:httpotion, ">= 3.1.3", only: [:dev, :test, :integration], runtime: false},
      {:excoveralls, "~> 0.12", only: :test},
      {:b64url, path: path("b64url")},
      {:jiffy, path: path("jiffy")},
      {:jwtf, path: path("jwtf")},
      {:ibrowse, path: path("ibrowse"), override: true},
      {:credo, "~> 1.6.4", only: [:dev, :test, :integration], runtime: false}
    ]

    # Some deps may be missing during source check
    # Besides we don't want to spend time checking them anyway
    List.foldl([:b64url, :jiffy, :jwtf, :ibrowse], deps_list, fn dep, acc ->
      if File.dir?(acc[dep][:path]) do
        acc
      else
        List.keydelete(acc, dep, 0)
      end
    end)
  end

  defp path(app) do
    lib_dir = Path.expand("src", __DIR__)
    Path.expand(app, lib_dir)
  end

  def get_test_paths(:test) do
    Path.wildcard("src/*/test/exunit") |> Enum.filter(&File.dir?/1)
  end

  def get_test_paths(:integration) do
    integration_tests =
      Path.wildcard("src/*/test/integration") |> Enum.filter(&File.dir?/1)

    ["test/elixir/test" | integration_tests]
  end

  def get_test_paths(_) do
    []
  end

  defp get_deps_paths() do
    deps = [
      "bunt",
      "certifi",
      "credo",
      "excoveralls",
      "hackney",
      "httpotion",
      "ibrowse",
      "idna",
      "jason",
      "jiffy",
      "junit_formatter",
      "metrics",
      "mimerl",
      "parse_trans",
      "ssl_verify_fun",
      "unicode_util_compat",
      "b64url",
      "exxhash",
      "mochiweb",
      "snappy",
      "rebar",
      "proper",
      "mochiweb",
      "meck",
      "khash",
      "hyper",
      "fauxton"
    ]

    deps |> Enum.map(fn app -> "src/#{app}" end)
  end

  defp get_coverage_paths() do
    deps =
      get_deps_paths()
      |> Enum.reduce(MapSet.new(), fn x, set ->
        MapSet.put(set, "#{x}/ebin")
      end)

    Path.wildcard("src/*/ebin")
    |> Enum.filter(&File.dir?/1)
    |> Enum.filter(fn path -> not MapSet.member?(deps, path) end)
  end
end
