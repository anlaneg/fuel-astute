module Astute
  module Network

    def self.check_network(ctx, nodes)
      if nodes.empty?
        Astute.logger.info(
          "#{ctx.task_id}: Network checker: nodes list is empty. Nothing to check.")
        return {
          'status' => 'error',
          'error' => "Nodes list is empty. Nothing to check."
        }
      elsif nodes.length == 1
        Astute.logger.info(
          "#{ctx.task_id}: Network checker: nodes list contains one node only. Do nothing.")
        return {'nodes' => [{
          'uid' => nodes[0]['uid'],
          'networks' => nodes[0]['networks']
        }]}
      end

      uids = nodes.map { |node| node['uid'].to_s }
      # TODO Everything breakes if agent not found. We have to handle that
      net_probe = MClient.new(ctx, "net_probe", uids)

      start_frame_listeners(ctx, net_probe, nodes)
      ctx.reporter.report({'progress' => 30})

      send_probing_frames(ctx, net_probe, nodes)
      ctx.reporter.report({'progress' => 60})

      net_probe.discover(:nodes => uids)
      stats = net_probe.get_probing_info
      result = format_result(stats)
      Astute.logger.debug "#{ctx.task_id}: Network checking is done. Results: #{result.inspect}"

      {'nodes' => result}
    end

    private
    def self.start_frame_listeners(ctx, net_probe, nodes)
      nodes.each do |node|
        data_to_send = make_interfaces_to_send(node['networks'])

        Astute.logger.debug(
          "#{ctx.task_id}: Network checker listen: node: #{node['uid']} data: #{data_to_send.inspect}")

        net_probe.discover(:nodes => [node['uid'].to_s])
        net_probe.start_frame_listeners(:interfaces => data_to_send.to_json)
      end
    end

    def self.send_probing_frames(ctx, net_probe, nodes)
      nodes.each do |node|
        data_to_send = make_interfaces_to_send(node['networks'])

        Astute.logger.debug(
          "#{ctx.task_id}: Network checker send: node: #{node['uid']} data: #{data_to_send.inspect}")

        net_probe.discover(:nodes => [node['uid'].to_s])
        net_probe.send_probing_frames(:interfaces => data_to_send.to_json)
      end
    end

    def self.make_interfaces_to_send(networks)
      data_to_send = {}
      networks.each do |network|
        data_to_send[network['iface']] = network['vlans'].join(",")
      end

      data_to_send
    end

    def self.format_result(stats)
      stats.map do |node|
        {
          'uid' => node.results[:sender],
          'networks' => check_vlans_by_traffic(
            node.results[:sender],
            node.results[:data][:neighbours])
        }
      end
    end

    def self.check_vlans_by_traffic(uid, data)
      data.map do |iface, vlans|
        {
          'iface' => iface,
          'vlans' => vlans.reject{ |k, v|
            v.size == 1 && v.has_key?(uid)
          }.keys.map(&:to_i)
        }
      end
    end

  end
end
