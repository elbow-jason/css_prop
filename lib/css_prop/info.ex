defmodule CssProp.Info do
  alias CssProp.Info

  defstruct [:name, :introduced, :support, :specs, :values, :prefixes, :prefix_notes, :notes]

  def from_yaml_file(path) do
    path
    |> File.read!()
    |> String.replace("\t", "    ")
    |> :yamerl.decode()
    |> Enum.flat_map(&parse_raw_yamerl_obj/1)
  end

  defp parse_raw_yamerl_obj(:null), do: []
  defp parse_raw_yamerl_obj([{_,_} | _] = yml) do
    kwargs = Enum.flat_map(yml, fn
        {'name', name} -> [name: to_string(name)]
        {'introduced', introduced} -> [introduced: to_string(introduced)]
        {'support', support} -> [support: map(support, &to_string/1, &support_value_mapper/1)]
        {'specs', specs} -> [specs: map(specs, &to_string/1)]
        {'values', values} -> [values: map(values, &values_key_mapper/1, &values_value_mapper/1)]
        {'prefixes', lol_chars} ->
          notes = map(lol_chars, &to_string/1)
          prefixes = notes |> map(&parse_prefixes/1) |> List.flatten()
          [prefix_notes: notes, prefixes: prefixes]
        {'notes', notes} ->
          [notes: map(notes, &to_string/1)]
        {key, value} ->
          [{to_string(key), map(value, &to_string/1)}]
      end)
    [build(kwargs)]
  end

  defp build(kwargs) do
    %Info{
      name: kwargs[:name],
      introduced: kwargs[:introduced],
      support: kwargs[:support],
      specs: kwargs[:specs],
      values: kwargs[:values],
      prefixes: kwargs[:prefixes],
      prefix_notes: kwargs[:prefix_notes],
      notes: kwargs[:notes],
    }
  end

  defp map(data, key_mapper, value_mapper \\ fn x -> x end)

  defp map(:null, _key_mapper, _value_mapper) do
    nil
  end

  defp map(i, _key_mapper, _value_mapper) when is_integer(i) do
    to_string(i)
  end

  defp map(data, key_mapper, value_mapper) when is_list(data) do
    Enum.map(data, fn
      {k, v} -> {key_mapper.(k), value_mapper.(v)}
      k -> key_mapper.(k)
    end)
  end

  defp values_key_mapper(k) do
    k
    |> to_string()
    |> case do
      "List of <image>s" ->
        {:list, "<image>"}
      "List of " <> kind ->
        {:list, kind}
      str ->
        str
    end
  end

  defp values_value_mapper(:null), do: nil

  defp values_value_mapper([{_, _} | _] = nested) do
    parse_raw_yamerl_obj(nested)
  end

  defp values_value_mapper(chars) when is_list(chars), do: to_string(chars)


  defp support_value_mapper([major]) when is_integer(major) do
    %Version{major: major, minor: 0, patch: 0}
  end

  defp support_value_mapper([v]) when is_float(v) do
    support_value_mapper(v)
  end

  defp support_value_mapper(['Yes']) do
    %Version{major: 1, minor: 0, patch: 0}
  end

  defp support_value_mapper(['yes']) do
    %Version{major: 1, minor: 0, patch: 0}
  end


  defp support_value_mapper(['1?']) do
    %Version{major: 1, minor: 0, patch: 0}
  end

  defp support_value_mapper('5 (alt)') do
    %Version{major: 5, minor: 0, patch: 0}
  end

  defp support_value_mapper('< 14') do
    %Version{major: 14, minor: 0, patch: 0}
  end

  defp support_value_mapper([[8804, 32 | chars]]) do
    {:"<=", %Version{major: chars |> to_string() |> String.to_integer(), minor: 0, patch: 0}}
  end

  defp support_value_mapper([8804 | chars]) do
    v =
      chars
      |> to_string()
      |> parse_number()
      |> support_value_mapper()
    {:"<=", v}
  end

  defp support_value_mapper([major, minor]) do
    %Version{major: major, minor: minor, patch: 0}
  end

  defp support_value_mapper([major, minor, patch]) do
    %Version{major: major, minor: minor, patch: patch}
  end

  defp support_value_mapper(major) when is_integer(major) do
    %Version{major: major, minor: 0, patch: 0}
  end

  defp support_value_mapper(v) when is_float(v) do
    v
    |> to_string()
    |> Kernel.<>(".0")
    |> Version.parse!()
  end

  @prefix_regex ~r/`-[-a-z]+-`/

  defp parse_prefixes(note) do
    @prefix_regex
    |> Regex.run(note)
    |> case do
      prefixes when is_list(prefixes) ->
        Enum.map(prefixes, fn p -> p |> String.replace("`", "") end)
      nil ->
        []
    end
  end

  def parse_number(str) do
    with(
      {_, r} when r != "" <- str |> String.trim() |> Float.parse(),
      {_, r} when r != "" <- str |> String.trim() |> Integer.parse()
    ) do
      raise "Invalid version string #{inspect(str)}"
    else
      :error ->
        raise "Invalid version string #{inspect(str)}"
      {f, ""} when is_float(f) ->
        f
      {i, ""} when is_integer(i) ->
        i
    end

  end
end
