defmodule AbnfParsec do
  alias AbnfParsec.{Parser, Generator}

  @doc """
  Example usage:

      defmodule JsonParser do
        use AbnfParsec,
          abnf_file: "test/fixture/json.abnf",
          parse: :json_text,
          ignored: [
            "name-separator",
            "value-separator",
            "quotation-mark",
            "begin-object",
            "end-object",
            "begin-array",
            "end-array"
          ],
          untagged: ["member"],
          unwrapped: ["null", "true", "false"],
          unboxed: ["JSON-text", "digit1-9", "decimal-point"]
      end
  """
  defmacro __using__(opts) do
    abnf =
      case Keyword.fetch(opts, :abnf_file) do
        {:ok, filepath} -> File.read!(filepath)
        :error -> Keyword.fetch!(opts, :abnf)
      end

    debug? = Keyword.get(opts, :debug, false)

    parse = Keyword.get(opts, :parse)

    code =
      abnf
      |> Parser.parse!()
      |> Generator.generate(Enum.into(opts, %{}))

    if debug? do
      code
      |> Macro.to_string()
      |> Code.format_string!()
      |> IO.puts()
    end

    quote do
      import NimbleParsec

      unquote(Generator.core())

      unquote(code)

      if unquote(parse) do
        def parse(text) do
          text |> unquote({parse, [], []})
        end

        def parse!(text) do
          case parse(text) do
            {:ok, syntax, "", _, _, _} ->
              syntax

            {:ok, _, leftover, _, _, _} ->
              raise AbnfParsec.LeftoverTokenError, "Leftover: #{leftover}"

            {:error, error, _, _, _, _} ->
              raise AbnfParsec.UnexpectedTokenError, error
          end
        end
      end
    end
  end
end
