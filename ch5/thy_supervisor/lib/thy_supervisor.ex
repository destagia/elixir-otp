defmodule ThySupervisor do
  use GenServer

  def karma do
    {:ok, sup_pid} = ThySupervisor.start_link([])
    IO.puts "start supervisor"
    IO.puts "child count: #{ThySupervisor.count_children(sup_pid)}"

    {:ok, child_pid} = ThySupervisor.start_child(sup_pid, {ThyWorker, :start_link, []})
    IO.puts "start child"
    IO.puts "child count: #{ThySupervisor.count_children(sup_pid)}"

    IO.puts "which children: #{inspect ThySupervisor.which_children(sup_pid)}"
    Process.exit(child_pid, "bukkoroshi")
    IO.puts "after terminating child"
    IO.puts "which children: #{inspect ThySupervisor.which_children(sup_pid)}"

    sup_pid
  end

  def start_link(child_spec_list) do
    GenServer.start_link(__MODULE__, [child_spec_list])
  end

  def terminate(_reason, state) do
    terminate_children(state)
    :ok
  end

  def terminate_children(child_specs) do
    for {pid, _} <- child_specs do
      terminate_child(pid)
    end
    :ok
  end

  def count_children(supervisor) do
    GenServer.call(supervisor, :count_children)
  end

  def which_children(supervisor) do
    GenServer.call(supervisor, :which_children)
  end

  def start_child(supervisor, child_spec) do
    GenServer.call(supervisor, {:start_child, child_spec})
  end

  def terminate_child(pid) do
    Process.exit(pid, :kill)
    :ok
  end
  def terminate_child(supervisor, pid) when is_pid(pid) do
    GenServer.call(supervisor, {:terminate_child, pid})
  end

  def handle_call(:count_children, _from, state) do
    {:reply, HashDict.size(state), state}
  end

  def handle_call(:which_children, _from, state) do
    {:reply, state, state}
  end
  
  def handle_call({:start_child, child_spec}, _from, state) do
    case start_child(child_spec) do
      {:ok, pid} ->
	new_state = HashDict.put(state, pid, child_spec)
	{:reply, {:ok, pid}, new_state}
      :error ->
	:Error
    end
  end

  def handle_call({:terminate_child, pid}, _from, state) do
    case terminate_child(pid) do
      :ok ->
	new_state = HashDict.delete(state, pid)
	{:reply, :ok, new_state}
      :error ->
	{:reply, {:error, "couldn't terminate child"}, state}
    end
  end

  def handle_info({:EXIT, from, :killed}, state) do
    new_state = state |> HashDict.delete(from)
    {:noreply, new_state}
  end
  def handle_info({:EXIT, from, :normal}, state) do
    # delete the element of child who got dead
    new_state = HashDict.delete(state, from)
    {:noreply, new_state}
  end
  ##
  ## Restart the child when it crashed!
  ##
  def handle_info({:EXIT, old_pid, _reason}, state) do
    IO.puts "restart child!"
    case HashDict.fetch(state, old_pid) do
      {:ok, child_spec} ->
	case restart_child(old_pid, child_spec) do
	  {:ok, {pid, child_spec}} ->
	    new_state = state
	    |> HashDict.delete(old_pid)
	    |> HashDict.put(pid, child_spec)
	    {:noreply, new_state}
	  :error ->
	    {:noreply, state}
	end
      _ ->
	{:noreply, state}
    end
  end
  
  def init([child_spec_list]) do
    # supervisor shouldn't restart automatically!
    # handle it by scratching
    Process.flag(:trap_exit, true)

    # create state for GenServer
    # it's list of pids for children
    state = child_spec_list
    |> start_children
    |> Enum.into(HashDict.new) # [{1, "ichi"}, ...] -> { 1: "ichi", ... }

    {:ok, state}
  end

  defp start_child({mod, fun, args}) do
    # create a process with particular worker module
    case apply(mod, fun, args) do
      pid when is_pid(pid) ->
	Process.link(pid)
	{:ok, pid}
      _ ->
	:erorr
    end
  end

  defp start_children([]) do
    []
  end
  defp start_children([child_spec | rest]) do
    case start_child(child_spec) do
      {:ok, pid} ->
	[{pid, child_spec} | start_children(rest)]
      :error ->
	:error
    end
  end

  defp restart_child(pid, child_spec) do
    case terminate_child(pid) do
      :ok ->
	case start_child(child_spec) do
    	  {:ok, new_pid} ->
	    {:ok, {new_pid, child_spec}}
	  :error ->
	    :error
	end
      :error ->
	:error
    end
  end
end
