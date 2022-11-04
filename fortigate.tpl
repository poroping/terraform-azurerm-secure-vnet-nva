Content-Type: multipart/mixed; boundary="===============0086047718136476635=="
MIME-Version: 1.0

--===============0086047718136476635==
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="config"

config system sdn-connector
	edit AzureSDN
		set type azure
	end
end
config sys global
    set admintimeout 120
    set hostname "${fortigate_vm_name}"
    set timezone 80
    set gui-theme mariner
    set admin-sport 10443
    set gui-firmware-upgrade-warning disable
    set gui-forticare-registration-setup-warning disable
end
config sys api-user
    edit sensa-tf
        set api-key ${apikey}
        set accprofile super_admin
        set vdom root
    next
end
config router static
    edit 1
        set gateway ${fortigate_external_gw}
        set device port1
    next
    edit 2
        set dst 168.63.129.16 255.255.255.255
        set device port2
        set gateway ${fortigate_internal_gw}
    next
    edit 3
        set dst 168.63.129.16 255.255.255.255
        set device port1
        set gateway ${fortigate_external_gw}
    next
    edit 4
        set dst ${route_server_1} 255.255.255.255
        set device port2
        set gateway ${fortigate_internal_gw}
    next
    edit 5
        set dst ${route_server_2} 255.255.255.255
        set device port2
        set gateway ${fortigate_internal_gw}
    next
end
config system probe-response
    set http-probe-value OK
    set mode http-probe
end
config system interface
    edit fortilink
        set ip 0.0.0.0/0
    next
    edit port1
        set mode static
        set ip ${fortigate_external_ipaddr}/${fortigate_external_mask}
        set description external
        set allowaccess probe-response ping https ssh ftm
    next
    edit port2
        set mode static
        set ip ${fortigate_internal_ipaddr}/${fortigate_internal_mask}
        set description internal
        set allowaccess probe-response ping https ssh ftm
    next

end

config router aspath-list
    edit "azure_internal"
        config rule
            edit 10
                set action permit
                set regexp "^65515$"
            next
        end
    next
end

config router route-map
    edit "rm_replace_az_internal_asn"
        set comments "Force replace the Azure internal ASN to allow routes to be shared inter-regionally"
        config rule
            edit 10
                set match-as-path "azure_internal"
                set set-aspath-action replace
                set set-aspath ${bgp_asn + bgp_offset}
            next
        end
    next
end

%{ if ilb }
config router route-map
    edit "rm_az_ilb_next_hop"
        set comments "Set all outbound route next-hops to Azure ILB"
        config rule
            edit 10
                set set-ip-nexthop ${ilb_ip}
            next
        end
    next
end
%{ endif }

config router bgp
    set as ${bgp_asn}
    set router-id ${routerid}
    set ibgp-multipath enable
    set ebgp-multipath enable
    set additional-path enable
    set recursive-next-hop enable
    set additional-path-select 8
    config neighbor
            edit ${route_server_1}
            set capability-graceful-restart enable
            set capability-route-refresh enable
            set ebgp-enforce-multihop enable
            set link-down-failover enable
            set soft-reconfiguration enable
            set description "RouteServer01"
            set interface "port2"
            set remote-as 65515
            set update-source "port2"
            set connect-timer 5
            set advertisement-interval 1
            set keep-alive-timer 60 
            set holdtime-timer 180
            set route-map-in "rm_replace_az_internal_asn"
            %{if ilb}set route-map-out "rm_az_ilb_next_hop"%{ endif }
        next
            edit ${route_server_2}
            set capability-graceful-restart enable
            set capability-route-refresh enable
            set ebgp-enforce-multihop enable
            set link-down-failover enable
            set soft-reconfiguration enable
            set description "RouteServer02"
            set interface "port2"
            set remote-as 65515
            set update-source "port2"
            set connect-timer 5
            set advertisement-interval 1
            set keep-alive-timer 60 
            set holdtime-timer 180
            set route-map-in "rm_replace_az_internal_asn"
            %{if ilb}set route-map-out "rm_az_ilb_next_hop"%{ endif }
        next
    end
end
%{ if fortigate_ha }
config system cluster-sync
    edit 0
        set peerip ${fortigate_ha_peerip}
        set ipsec-tunnel-sync disable
    next
end
config system standalone-cluster
    set standalone-group-id 1
    set group-member-id ${ha_memberid}
    set layer2-connection unavailable
    unset session-sync-dev
    set encryption enable
    set psksecret ${ha_enc_psk}
end
config system ha
    set session-pickup enable
    set session-pickup-connectionless enable
    set session-pickup-expectation enable
    set session-pickup-nat enable
    set session-pickup-delay disable
end
%{ endif }
%{if elb }
config system interface
    edit "LOOP-SSLVPN"
        set vdom root
        set type loopback
        set ip ${elb_ip}/32
        set allowaccess ping probe-response
    next
end

config vpn ssl settings
    set status enable
    set https-redirect enable
    set servercert Fortinet_Factory
    set tunnel-ip-pools "SSLVPN_TUNNEL_ADDR1"
    set tunnel-ipv6-pools "SSLVPN_TUNNEL_IPv6_ADDR1"
    set port 443
    set source-interface "LOOP-SSLVPN"
    set source-address "all"
    set source-address6 "all"
    set default-portal "full-access"
end

config firewall policy
    edit 0
        set name "SSLVPN-IN"
        set srcintf "port1"
        set dstintf "LOOP-SSLVPN"
        set action accept
        set srcaddr "all"
        set dstaddr "all"
        set schedule "always"
        set service "ALL"
    next
end
%{ endif }
%{ if fortigate_license != "" }
--===============0086047718136476635==--
Content-Type: text/plain; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="license"

${fortigate_license}

%{ endif }
--===============0086047718136476635==--