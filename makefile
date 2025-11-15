-include .env

.PHONY: all test deploy

deploy-anvil:
	@echo "Deploying to local Anvil..."
	@forge script script/DeployMyToken.s.sol:DeployMyToken --broadcast --rpc-url ${ANVIL_RPC_URL} --account toluWallet
	
get-owner-balance:
	@cast call 0x95bd8d42f30351685e96c62eddc0d0613bf9a87a "balanceOf(address)" 0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f