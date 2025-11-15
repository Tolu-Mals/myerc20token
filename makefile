-include .env

.PHONY: all test deploy

deploy-anvil:
	@echo "Deploying to local Anvil..."
	@forge script script/DeployMyToken.s.sol:DeployMyToken --broadcast --rpc-url ${ANVIL_RPC_URL} --account localAnvil