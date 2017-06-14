defmodule Metex do
  def get_temperature(location) do
    {:ok, worker} = Metex.Worker.start_link()
    temp = worker |> Metex.Worker.get_temperature("Tokyo")
    IO.puts(temp)
  end
end
