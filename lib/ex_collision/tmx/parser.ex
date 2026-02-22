defmodule ExCollision.TMX.Parser do
  @moduledoc """
  Parser for Tiled TMX files (XML).
  Supports tile layers (CSV/base64), objectgroup, tilesets.
  """

  import SweetXml

  alias ExCollision.TMX.{Map, Tileset, TileLayer, ObjectGroup, MapObject}

  @doc """
  Parses TMX file by path or XML content.

  ## Examples

      iex> ExCollision.TMX.Parser.parse!("data/Dun.tmx")
      %ExCollision.TMX.Map{...}

      iex> ExCollision.TMX.Parser.parse!(xml_string)
      %ExCollision.TMX.Map{...}
  """
  @spec parse!(Path.t() | String.t()) :: Map.t()
  def parse!(path) when is_binary(path) do
    path
    |> File.read!()
    |> parse_xml!()
  end

  def parse!(content) when is_binary(content) do
    parse_xml!(content)
  end

  @spec parse_xml!(String.t()) :: Map.t()
  def parse_xml!(xml) do
    doc = SweetXml.parse(xml)
    map_el = xpath(doc, ~x"//map"e)
    build_map(map_el)
  end

  defp build_map(map_el) do
    tilesets = parse_tilesets(map_el)
    layers = parse_layers(map_el)

    %Map{
      version: xpath(map_el, ~x"./@version"s) || "",
      orientation: xpath(map_el, ~x"./@orientation"s) || "orthogonal",
      width: (xpath(map_el, ~x"./@width"s) || "") |> parse_int(),
      height: (xpath(map_el, ~x"./@height"s) || "") |> parse_int(),
      tile_width: (xpath(map_el, ~x"./@tilewidth"s) || "") |> parse_int(),
      tile_height: (xpath(map_el, ~x"./@tileheight"s) || "") |> parse_int(),
      render_order: xpath(map_el, ~x"./@renderorder"s) || "right-down",
      next_layer_id: (xpath(map_el, ~x"./@nextlayerid"s) || "") |> parse_int(),
      next_object_id: (xpath(map_el, ~x"./@nextobjectid"s) || "") |> parse_int(),
      tilesets: tilesets,
      layers: layers
    }
  end

  defp parse_tilesets(map_el) do
    map_el
    |> xpath(~x"./tileset"l)
    |> Enum.map(&tileset_from_xml/1)
  end

  defp tileset_from_xml(ts_el) do
    %Tileset{
      first_gid: (xpath(ts_el, ~x"./@firstgid"s) || "") |> parse_int(),
      name: xpath(ts_el, ~x"./@name"s) || "",
      tile_width: (xpath(ts_el, ~x"./@tilewidth"s) || "") |> parse_int(),
      tile_height: (xpath(ts_el, ~x"./@tileheight"s) || "") |> parse_int(),
      columns: (xpath(ts_el, ~x"./@columns"s) || "") |> parse_int_opt(),
      tile_count: (xpath(ts_el, ~x"./@tilecount"s) || "") |> parse_int_opt()
    }
  end

  defp parse_layers(map_el) do
    # Preserve layer order: all layer first, then objectgroup (XPath order)
    layers_el = xpath(map_el, ~x"./layer"l)
    groups_el = xpath(map_el, ~x"./objectgroup"l)

    layer_list =
      Enum.map(layers_el, fn el -> tile_layer_from_xml(el) end) ++
        Enum.map(groups_el, fn el -> object_group_from_xml(el) end)

    layer_list
  end

  defp tile_layer_from_xml(el) do
    data_el = xpath(el, ~x"./data"e)
    encoding = if data_el != nil, do: xpath(data_el, ~x"./@encoding"s) || "csv", else: "csv"
    compression = if data_el != nil, do: xpath(data_el, ~x"./@compression"s) || "", else: ""
    raw = if data_el != nil, do: xpath(data_el, ~x"./text()"s) |> trim_cdata(), else: ""
    width = (xpath(el, ~x"./@width"s) || "") |> parse_int()
    height = (xpath(el, ~x"./@height"s) || "") |> parse_int()
    gids = decode_layer_data(raw, encoding, compression, width * height)

    %TileLayer{
      id: (xpath(el, ~x"./@id"s) || "") |> parse_int(),
      name: xpath(el, ~x"./@name"s) || "",
      width: width,
      height: height,
      opacity: xpath(el, ~x"./@opacity"s) |> parse_float_opt() || 1.0,
      visible: (xpath(el, ~x"./@visible"s) || "1") != "0",
      data: gids
    }
  end

  defp object_group_from_xml(el) do
    objects =
      el
      |> xpath(~x"./object"l)
      |> Enum.map(&map_object_from_xml/1)

    %ObjectGroup{
      id: (xpath(el, ~x"./@id"s) || "") |> parse_int(),
      name: xpath(el, ~x"./@name"s) || "",
      visible: (xpath(el, ~x"./@visible"s) || "1") != "0",
      objects: objects
    }
  end

  defp map_object_from_xml(obj_el) do
    polygon = (xpath(obj_el, ~x"./polygon/@points"s) || "") |> parse_points()
    polyline = (xpath(obj_el, ~x"./polyline/@points"s) || "") |> parse_points()

    %MapObject{
      id: (xpath(obj_el, ~x"./@id"s) || "") |> parse_int_opt(),
      gid: (xpath(obj_el, ~x"./@gid"s) || "") |> parse_int_opt(),
      name: xpath(obj_el, ~x"./@name"s) || "",
      type: xpath(obj_el, ~x"./@type"s) || "",
      x: (xpath(obj_el, ~x"./@x"s) || "") |> parse_float(),
      y: (xpath(obj_el, ~x"./@y"s) || "") |> parse_float(),
      width: (xpath(obj_el, ~x"./@width"s) || "") |> parse_float_opt(),
      height: (xpath(obj_el, ~x"./@height"s) || "") |> parse_float_opt(),
      rotation: xpath(obj_el, ~x"./@rotation"s) |> parse_float_opt() || 0,
      visible: (xpath(obj_el, ~x"./@visible"s) || "1") != "0",
      polygon_points: polygon,
      polyline_points: polyline
    }
  end

  defp parse_points(""), do: []
  defp parse_points(nil), do: []

  defp parse_points(str) when is_list(str), do: parse_points(to_string(str))

  defp parse_points(str) when is_binary(str) do
    str
    |> String.trim()
    |> String.split(~r/\s+/)
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(fn pair ->
      [x, y] = String.split(pair, ",")
      {String.to_float(x), String.to_float(y)}
    end)
  end

  defp decode_layer_data(raw, "csv", _compression, expected_len) do
    gids =
      raw
      |> String.replace(~r/\s+/, ",")
      |> String.split(",", trim: true)
      |> Enum.map(&parse_gid/1)

    pad_to_length(gids, expected_len)
  end

  defp decode_layer_data(raw, "base64", "", expected_len) do
    raw
    |> String.replace(~r/\s+/, "")
    |> Base.decode64!(padding: false)
    |> decode_gids_32_le(expected_len)
  end

  defp decode_layer_data(raw, "base64", "zlib", expected_len) do
    raw
    |> String.replace(~r/\s+/, "")
    |> Base.decode64!(padding: false)
    |> :zlib.uncompress()
    |> decode_gids_32_le(expected_len)
  end

  defp decode_layer_data(raw, "base64", "gzip", expected_len) do
    raw
    |> String.replace(~r/\s+/, "")
    |> Base.decode64!(padding: false)
    |> :zlib.gunzip()
    |> decode_gids_32_le(expected_len)
  end

  defp decode_layer_data(raw, _enc, _comp, _expected_len) do
    decode_layer_data(raw, "csv", nil, 0)
  end

  defp decode_gids_32_le(binary, expected_len) do
    gids = for <<gid::little-32 <- binary>>, do: strip_flags(gid)
    pad_to_length(gids, expected_len)
  end

  defp pad_to_length(gids, expected_len) when expected_len > 0 do
    n = length(gids)
    if n < expected_len, do: gids ++ List.duplicate(0, expected_len - n), else: gids
  end

  defp pad_to_length(gids, _), do: gids

  defp strip_flags(gid) when gid == 0, do: 0
  defp strip_flags(gid), do: Bitwise.band(gid, 0x0FFF_FFFF)

  defp parse_gid(str) do
    case Integer.parse(str) do
      {n, _} -> strip_flags(n)
      :error -> 0
    end
  end

  defp parse_int(nil), do: 0
  defp parse_int(""), do: 0
  defp parse_int(s) when is_list(s), do: s |> to_string() |> parse_int()

  defp parse_int(s) when is_binary(s) do
    case Integer.parse(String.trim(s)) do
      {n, _} -> n
      :error -> 0
    end
  end

  defp parse_int_opt(nil), do: nil
  defp parse_int_opt(""), do: nil
  defp parse_int_opt(s) when is_list(s), do: s |> to_string() |> parse_int_opt()

  defp parse_int_opt(s) when is_binary(s) do
    case Integer.parse(String.trim(s)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp parse_float(nil), do: 0.0
  defp parse_float(""), do: 0.0
  defp parse_float(s) when is_list(s), do: s |> to_string() |> parse_float()

  defp parse_float(s) when is_binary(s) do
    case Float.parse(String.trim(s)) do
      {n, _} -> n
      :error -> 0.0
    end
  end

  defp parse_float_opt(nil), do: nil
  defp parse_float_opt(""), do: nil
  defp parse_float_opt(s) when is_list(s), do: s |> to_string() |> parse_float_opt()

  defp parse_float_opt(s) when is_binary(s) do
    case Float.parse(String.trim(s)) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp trim_cdata(nil), do: ""
  defp trim_cdata(s) when is_list(s), do: s |> to_string() |> String.trim()
  defp trim_cdata(s) when is_binary(s), do: String.trim(s)
end
