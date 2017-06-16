defmodule Metex.Worker do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    {:ok, %{}}
  end

  ## Client API

  # Client get temperature with instance of Worker
  # ```
  #   {:ok, worker_pid} = Metex.Worker.start_link()
  #   temperature = Metex.Worker.get_temperature(worker_pid, "Tokyo")
  #   IO.puts("the temperature: #{temperature}")
  # ```
  def get_temperature(pid, location) do
    GenServer.call(pid, {:location, location})
  end

  def get_state(pid) do
    GenServer.call(pid, :get_state)
  end

  def reset_state(pid) do
    GenServer.cast(pid, :reset_state)
  end

  ## Server API

  def handle_call({:location, location}, _from, state) do
    case temperature_of(location) do
      {:ok, temp} ->
	new_state = update_state(state, location)
	{:reply, "#{temp}", new_state}
      _ ->
	{:reply, :error, state}
    end
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast(:reset_state, _state) do
    {:noreply, %{}}
  end

  # count the count that a location is refered
  defp update_state(old_state, location) do
    if Map.has_key?(old_state, location) do
      Map.update!(old_state, location, &(&1 + 1))
    else
      Map.put_new(old_state, location, 1)
    end
  end

  ## Worker core implementation

  defp temperature_of(location) do
    url = url_for(location)
    HTTPoison.get(url) |> parse_response()
  end

  defp url_for(location) do
    location = URI.encode(location)
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{api_key()}"
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    body |> JSON.decode! |> compute_temperature
  end
  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temperature = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok ,temperature}
    rescue
      _ -> :error
    end
  end
  
  defp api_key() do
    "85f1d1f0518b2ad889b064b7aecede67"
  end
end
