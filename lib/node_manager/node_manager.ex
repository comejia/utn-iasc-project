defmodule NodeManager do
    use GenServer
    require Logger

    @max_capacity 2

    def start_link(_init_arg) do
        GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    end

    def init(state) do
        {:ok, state}
    end

    def handle_call({:insert, key, value}, _from_pid, state) do
        data_node = emptiest_data_node()
        if map_size(:erpc.call(data_node, DatoAgent,:getAll,[])) >= @max_capacity
        do
            Logger.info("base de datos llena")
        else
            agent = :erpc.call(data_node,DatoRegistry,:find_agents,[]) |> List.first
            agent_value = elem(agent,2)
            replicas = Enum.filter([Node.self()|Node.list()], fn node -> String.contains?(to_string(node),agent_value) end)
            :erpc.call(data_node, DatoAgent, :insert, [key,value])
             if not Enum.empty?(replicas) do
                Enum.map(replicas,fn replica -> :erpc.call(replica,DatoAgent,:insert,[key,value]) end)
             end
        end
        {:reply,:ok,state}   
    end

    def handle_call({:delete, key}, _from_pid, state) do
        Enum.map(agent_node_list(), fn node -> :erpc.call(node,DatoAgent,:delete,[key]) end)
        {:reply, "dato borrado", state}
    end

    def handle_call({:get, key}, _from_pid, state) do
        result = get_value(key)
        {:reply, "el valor es: #{result}", state}
    end

    def handle_call({:get_all}, _from_pid, state) do
        dato_List = Enum.map(agent_node_list(), fn node -> :erpc.call(node,DatoAgent,:getAll,[])  end)
        datos = List.foldl(dato_List,%{}, fn x, acc -> Map.merge(acc, x) end)
        {:reply, datos,state}
    end

    def get_value(key) do
        values = Enum.map(agent_node_list(), fn node -> :erpc.call(node,DatoAgent,:get,[key]) end)
        Enum.filter(values, fn x -> not is_nil(x) end)
    end

    def insert(key, value) do
        pid = Process.whereis(NodeManager)
        GenServer.call(pid, {:insert, key, value})
    end

    def agent_list do
        agents = DatoRegistry.find_agents()
        agent_pids = Enum.map(agents, fn {_,x,_} -> x end)
    end
    
    def agent_node_list do
        Enum.filter([Node.self() | Node.list()], 
                    fn node -> not Enum.empty?(:erpc.call(node,DatoRegistry,:find_agents,[])) end)
    end

    def replica_node_list do
        Enum.filter([Node.self() | Node.list()], 
                    fn node -> not Enum.empty?(:erpc.call(node,DatoRegistry,:find_replicas,[])) end)
    end

    def next_agent(list) do
        agents = sort_by_most_empty(list)
        List.first(agents)
    end

    def get_replicas_of(value) do
        list = DatoRegistry.find_all
        replicas = DatoRegistry.find_replicas_for(value)
        Enum.map(replicas, fn {_,x,_} -> x end)
    end

    def emptiest_data_node() do
        agent_nodes = agent_node_list()
        data_list = Enum.map(agent_nodes, fn node -> :erpc.call(node,DatoAgent,:getAll,[]) end)
        lowest_size = Enum.map(data_list,fn x -> map_size(x) end) |> List.first
        Enum.filter(agent_nodes, fn node -> (:erpc.call(node,DatoAgent,:getAll,[]) |> map_size()) == lowest_size end) |> List.first
    end

    def sort_by_most_empty(list) do
        Enum.sort(list,&(DatoAgent.data_size(&1) <= DatoAgent.data_size(&2)))
    end

    # Logica Orquestadores
    def node_down(node_id) do
        orquestadores =
          OrquestadorHordeRegistry.get_all
          |>Enum.filter(fn {_, _, node} -> node != node_id end)

        if is_master_down(orquestadores) do
          {id, _pid, node} = orquestadores |> List.first
          Orquestador.set_as_master(id)
          Logger.info("---- Nuevo nodo master: #{node}, #{id} ----")
        end
    end

    def is_master_down(orquestadores) do
        orquestadores |> Enums.all?(fn {id, _, _} -> !Orquestador.is_master(id) end)
    end
    
    #eprc call
    #:erpc.call(node,DatoRegistry,:find_all_pids,[]) 
    #:erpc.call(Node.list,DatoAgent,:insert,[remote agent pid,:a,"a"])
    #multi call genserver
    #GenServer.multi_call([node() | Node.list()],NodeManager, {:insert,:a,"a"})
end