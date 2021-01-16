defmodule CssProp do
  @moduledoc """
  Documentation for `CssProp`.
  """

  @priv_dir :css_prop
    |> :code.priv_dir()
    |> to_string()

  @priv_subdirs @priv_dir
    |> File.ls!()
    |> Enum.map(fn dir -> Path.join([@priv_dir, dir, "properties"]) end)

  @files @priv_subdirs
    |> Enum.flat_map(fn dir ->
      dir
      |> File.ls!()
      |> Enum.map(fn f -> Path.join(dir, f) end)
    end)
  Module.register_attribute(__MODULE__, :info_list, accumulate: true)

  for f <- @files do
    for info <- CssProp.Info.from_yaml_file(f) do
      Module.put_attribute(__MODULE__, :info_list, {info.name, info})
    end
  end

  @info_map Enum.group_by(@info_list, fn {k, _} -> k end, fn {_, v} -> v end)

  for {name, infos} <- @info_map do
    @name name
    @infos infos
    def info(@name), do: @infos
  end

end
