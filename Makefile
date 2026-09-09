PI_HOST      ?= pegasus.local
PI_USER      ?= gobbi
REMOTE_DIR   ?= /home/gobbi/docker/homelab
ANSIBLE_DIR  := ansible

.PHONY: install-collections ping check deploy up down restart logs ps

install-collections:
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml

ping:
	ansible -i $(ANSIBLE_DIR)/inventory/hosts.ini pi -m ping

check:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.ini $(ANSIBLE_DIR)/site.yml --check --diff

deploy up:
	ansible-playbook -i $(ANSIBLE_DIR)/inventory/hosts.ini $(ANSIBLE_DIR)/site.yml

down:
	ssh $(PI_USER)@$(PI_HOST) "cd $(REMOTE_DIR) && docker compose down"

restart:
	ssh $(PI_USER)@$(PI_HOST) "cd $(REMOTE_DIR) && docker compose restart"

logs:
	ssh $(PI_USER)@$(PI_HOST) "cd $(REMOTE_DIR) && docker compose logs -f"

ps:
	ssh $(PI_USER)@$(PI_HOST) "cd $(REMOTE_DIR) && docker compose ps"
