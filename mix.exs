defmodule Kv.MixProject do
  use Mix.Project

  def project do
    [
      app: :kv,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :wx, :observer , :eex, :runtime_tools],
      mod: {KV.Application, []}
    ]
  end

  defp deps do
    [
      {:horde, "~> 0.8.3"},
      {:libcluster, "~> 3.3"},
      {:plug_cowboy, "~> 2.5"}
    ]
  end
end


#elixir --name node1@127.0.0.1 -S mix
#elixir --name node2@127.0.0.1 -S mix
