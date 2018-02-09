defmodule Relay.ProtobufUtil do
  alias Google.Protobuf.{Struct, NullValue, ListValue, Value}

  defp oneof_actual_vals(props, struct) do
    # Copy/pasta-ed from:
    # https://github.com/tony612/protobuf-elixir/blob/a4389fe18edc70430563d8591aa05bd3dba60adc/lib/protobuf/encoder.ex#L153-L160
    # TODO: Make this more readable
    Enum.reduce(props.oneof, %{}, fn {field, _}, acc ->
      case Map.get(struct, field) do
        {f, val} -> Map.put(acc, f, val)
        nil -> acc
      end
    end)
  end

  def mkstruct(%{__struct__: mod} = struct) do
    Protobuf.Validator.validate!(struct)

    props = mod.__message_props__()
    oneofs = oneof_actual_vals(props, struct)

    fields = props.field_props |> Enum.into(%{}, fn {_, prop} ->
      val = if prop.oneof do
        oneofs[prop.name_atom]
      else
        Map.get(struct, prop.name_atom)
      end

      {prop.name, struct_value(val)}
    end)
    Struct.new(fields: fields)
  end

  defp struct_value(nil), do: value(:null_value, NullValue.value(:NULL_VALUE))

  defp struct_value(number) when is_number(number), do: value(:number_value, number)

  defp struct_value(string) when is_binary(string), do: value(:string_value, string)

  defp struct_value(bool) when is_boolean(bool), do: value(:bool_value, bool)

  defp struct_value(%Struct{} = struct), do: value(:struct_value, struct)

  defp struct_value(%_{} = struct), do: value(:struct_value, mkstruct(struct))

  defp struct_value(list) when is_list(list) do
    values = list |> Enum.map(fn element -> struct_value(element) end)
    value(:list_value, ListValue.new(values: values))
  end

  defp value(kind, val), do: Value.new(kind: {kind, val})
end
