require 'em-websocket'
require 'yaml'
require 'rails'

# Sempre que este arquivo for alterado, deve-se matar manualmente o processo em producao e rodar o upgrade do projeto
# Always when this file is changed, the production proccess must be killed and then the upgrade of project must be done

class WebsocketServer
  config = YAML::load(File.open('config/global.yml'))[Rails.env.to_s]['websocket']
  EM.run do
    @subs = {} # list with subscribed users
    EventMachine::WebSocket.start(
        :host => config['host'],
        :port => config['port'],
        :secure => true,
        :tls_options => {
          :private_key_file => "/etc/ssl/nginx/cert.key",
          :cert_chain_file => "/etc/ssl/nginx/cert.crt"
        }
      ) do |ws|
      ws.onopen do |data|
        academic_allocation_id = data.path.split('/')[1]
        ac_subs = @subs[academic_allocation_id.to_sym]
        # add new client
        if ac_subs.nil?
          @subs[academic_allocation_id.to_sym] = [ws]
        else
          @subs[academic_allocation_id.to_sym] << ws
        end
      end
      ws.onmessage do |msg|
        # get academic_allocation
        subs = @subs[msg.split(':').last.delete('"}').to_sym].dup
        subs.delete(ws) # remove the client who have sent the message
        subs.each { |s| s.send msg }
      end
      ws.onclose do
        @subs.delete_if { |key| key == ws }
      end
    end
  end
end
