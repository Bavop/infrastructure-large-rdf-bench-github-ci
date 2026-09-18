INVENTORY ?= inventory-qlever.yml

.PHONY: ping get-ip common endpoints transfer

ping:        # Reachability of all hosts
	ansible all -i $(INVENTORY) -m ping

get-ip:      # Print each host's IP address
	ansible-playbook -i $(INVENTORY) get-ip.yml

common:      # Base provisioning on all nodes (disk, NAT, packages)
	ansible-playbook -i $(INVENTORY) common.yml

endpoints:   # Install Docker + pull the QLever image
	ansible-playbook -i $(INVENTORY) endpoints.yml

transfer:    # Build and serve every dataset's QLever endpoint behind Caddy
	ansible-playbook -i $(INVENTORY) transfer.yml
