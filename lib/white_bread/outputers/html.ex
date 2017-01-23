defmodule WhiteBread.Outputers.HTML do
  use GenServer
  alias WhiteBread.Gherkin.Elements.Scenario
  alias WhiteBread.Gherkin.Elements.ScenarioOutline
  alias WhiteBread.Gherkin.Elements.Feature
  alias WhiteBread.Outputers.HTML.Formatter

  @moduledoc """
  This generic server accumulates information about White Bread
  scenarios then formats them as HTML and outputs them to a file in
  one go.
  """

  defstruct pid: nil, path: nil, tree: %{}, data: []

  ## Client Interface

  @doc false
  def start do
    {:ok, outputer} = GenServer.start __MODULE__, []
    outputer
  end

  @doc false
  def stop(outputer) do
    :ok = GenServer.stop outputer, :normal
  end

  ## Interface to Generic Server Machinery

  def init(_) do
    {:ok, %__MODULE__{path: document_path()}}
  end

  def handle_cast({:scenario_result, {result, _}, %Scenario{name: name}}, state) when :ok == result or :failed == result do
    {:noreply, %{state | data: [{result, name}|state.data]}}
  end
  def handle_cast({:scenario_result, {_, _}, %ScenarioOutline{}}, state) do
    ## This clause here for more sophisticated report in the future.
    {:noreply, state}
  end
  def handle_cast({:scenario_result, _}, state) do
    ## This clause here for more sophisticated report in the future.
    {:noreply, state}
  end
  def handle_cast({:final_results, %{successes: [{%Feature{name: x}, _}|_], failures: _}}, state) do
    ## This clause here for more sophisticated report in the future.
    {:noreply, %{state | tree: Map.put(state.tree, x, state.data), data: []}}
  end
  def handle_cast(x, state) do
    require Logger

    Logger.warn "cast with #{inspect x}."
    {:noreply, state}
  end

  def terminate(_, %__MODULE__{data: content, path: path, tree: tree}) do
    IO.inspect content
    IO.inspect tree
    report_ tree, path
  end

  ## Internal

  defp document_path do
    case Keyword.fetch!(outputers(), __MODULE__) do
      [path: "/"] ->
        raise WhiteBread.Outputers.HTML.PathError
      [path: x] when is_binary(x) ->
        Path.expand x
    end
  end

  defp format({:ok,     name}), do: Formatter.success(name)
  defp format({:failed, name}), do: Formatter.failure(name)

  defp write(content, path) do
    File.mkdir_p!(parent path) && File.write!(path, content)
  end

  defp parent(path) do
    Path.join(drop(Path.split path))
  end

  defp drop(x) when is_list(x), do: x -- [List.last(x)]

  defmodule PathError do
    defexception message: "Given root directory."
  end

  defp report_(content, path) do
    import Formatter, only: [body: 1, document: 1]

    content
    |> elements
    |> sections
    |> IO.iodata_to_binary
    |> body
    |> document
    |> write(path)
  end

  defp outputers do
    Application.fetch_env!(:white_bread, :outputers)
  end

  defp elements(x) do
    Enum.map(x, &element/1)
  end

  defp element({suite, cases}) do
    {suite, Enum.map(cases, &format/1)}
  end

  defp sections(x) do
    Enum.map(x, &section/1)
  end

  defp section({name, children}) do
    Formatter.section(name, children)
  end
end
