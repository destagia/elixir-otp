defmodule Metex.Worker do
  def loop do
    receive do
      {sender_pid, location} ->
	send(sender_pid, {:ok, temperature_of(location)})
      _ ->
	IO.puts "unrecognized message is coming"
    end
    loop
  end
  
  def temperature_of(location) do
    result = url_for(location) |> HTTPoison.get |> parse_response
    case result do
      {:ok, temp} ->
	"#{location}: #{temp}"
      :error ->
	"#{location} was not found"
    end
  end

  defp url_for(location) do
    location = URI.encode(location);
    "http://api.openweathermap.org/data/2.5/weather?q=#{location}&appid=#{api_key}"
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    body |> JSON.decode! |> compute_temperature
  end
  defp parse_response(_) do
    :error
  end

  defp compute_temperature(json) do
    try do
      temp = (json["main"]["temp"] - 273.15) |> Float.round(1)
      {:ok ,temp}
    rescue
      _ -> :error
    end
  end
  
  defp api_key() do
    "85f1d1f0518b2ad889b064b7aecede67"
  end
end
