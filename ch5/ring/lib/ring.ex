defmodule Ring do
  def karma do
    IO.puts "create processes..."
    pids = create_processes(10)

    IO.puts "link processes..."
    link_processes(pids)

    for pid <- pids do
      IO.puts "#{inspect pid}: #{inspect Process.info(pid, :links)}"
    end

    IO.puts "alive all?: #{pids |> Enum.all?(fn pid -> Process.alive?(pid) end)}"

    crash_pid = pids |> Enum.shuffle |> List.first
    IO.puts "crash: #{inspect crash_pid}"
    send(crash_pid, :crash)

    IO.puts "check whether all process are killed"
    for pid <- pids do
      IO.puts "#{inspect pid} is alive?: #{Process.alive?(pid)}"
    end

    :ok
  end

  def create_processes(process_num) do
    1..process_num |> Enum.map(fn _ -> spawn(fn -> loop() end) end)
  end

  def loop do
    receive do
      {:link, link_to} when is_pid(link_to) ->
	Process.link(link_to)
      :crash ->
	IO.puts("#{1 / 0}") # this causes the process to crash!
    end
    loop()
  end

  def link_processes(processes) do
    link_processes(processes, [])
  end

  def link_processes([process_1, process_2 | rest], linked_processes) do
    send(process_1, {:link, process_2})
    link_processes([process_2 | rest], [process_1 | linked_processes])
  end

  def link_processes([process | []], linked_processes) do
    first_process = linked_processes |> List.last
    send(process, {:link, first_process})
    :ok
  end
end
