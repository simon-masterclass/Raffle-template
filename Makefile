-include .env

# Exclude the following targets from the default target
.PHONY: all test clean deploy fund help install snapshot format anvil zktest

#####################################################################################
# Global Variables
#####################################################################################

DEFAULT_ANVIL_PRIVATE_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
NINTH_ANVIL_PRIVATE_KEY := 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6
DEFAULT_ANVIL_CHAIN_ID := 1337
DEFAULT_ZKSYNC_LOCAL_KEY := 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110

# Help
help:
	@echo "Usage:" 
	@echo "      make deploy ARGS=\"...\" \n\n     example: make deploy ARGS=\"--network avalanche\""
	@echo ""
	@echo "      make fund ARGS=\"...\" \n\n     example: make fund ARGS=\"--network base\""
	@echo ""

# Clean the repo
clean  :; forge clean

all: clean remove install update build

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install cyfrin/foundry-devops@0.2.2 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@1.1.1 --no-commit && forge install foundry-rs/forge-std@v1.8.2 --no-commit

# Update Dependencies
update:; forge update

build:; forge build

zkbuild :; forge build --zksync

test :; forge test

zktest :; foundryup-zksync && forge test --zksync && foundryup

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

zk-anvil :; npx zksync-cli dev start

#####################################################################################
# Test Scripts
#####################################################################################
# Test the Raffle.sol:Raffle contract

test-fork-s:
	forge test --fork-url $(SEPOLIA_RPC_URL)

test-fork-s-vvv:
	forge test --fork-url $(SEPOLIA_RPC_URL) -vvv

#####################################################################################
# Deploy Scripts - Raffle.sol:Raffle
#####################################################################################

# Deploy the Raffle.sol:Raffle contract
# deployOnAnvil:
# 	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

# NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast
deploy-anvil: 
	forge script script/DeployRaffle.s.sol:DeployRaffle --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv

deployOnAnvil:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS_x)
# @dev This script will deploy to Anvil using the NINTH Anvil key account:
# Anvil: (9) 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (10000.000000000000000000 ETH) 
# The 9th account uses this private key: 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6 =  NINTH_ANVIL_PRIVATE_KEY 
# but only if the --network anvil flag is IS NOT passed using the following command:
# CMD: make deployOnAnvil
NETWORK_ARGS_x := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast -vvvv
# @dev This script will deploy to Anvil using the ZERO Anvil key account:
# Anvil: (0) 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000.000000000000000000 ETH)
# The 0th account uses this private key: (0) 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 =  DEFAULT_ANVIL_PRIVATE_KEY 
# but only if the --network anvil flag IS passed using the following command:
# CMD: make deployOnAnvil ARGS="--network anvil"
ifeq ($(findstring --network anvil,$(ARGS)),--network anvil)
	NETWORK_ARGS_x := --rpc-url http://localhost:8545 --private-key $(NINTH_ANVIL_PRIVATE_KEY) --broadcast -vvvv
endif


deployAvax:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)

ifeq ($(findstring --network avalanche,$(ARGS)),--network avalanche)
	NETWORK_ARGS := --rpc-url $(AVAX_RPC_URL) --private-key $(DEPLOYER_PKEY) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

#####################################################################################
# Deploy Scripts - FundMe.sol:FundMe (reference scripts)
#####################################################################################

# Deploy the Raffle.sol:Raffle contract
# deployOnAnvil:
# 	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS)
# FundMe.sol:FundMe contract deployment

deploy:
	@forge script script/DeployFundMe.s.sol:DeployFundMe $(NETWORK_ARGS)

NETWORK_ARGS := --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_PRIVATE_KEY) --broadcast

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --broadcast --verify --etherscan-api-key $(ETHERSCAN_API_KEY) -vvvv
endif

deploy-sepolia:
	@forge script script/DeployFundMe.s.sol:DeployFundMe $(NETWORK_ARGS)

# As of writing, the Alchemy zkSync RPC URL is not working correctly 
deploy-zk:
	forge create src/FundMe.sol:FundMe --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args $(shell forge create test/mock/MockV3Aggregator.sol:MockV3Aggregator --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --constructor-args 8 200000000000 --legacy --zksync | grep "Deployed to:" | awk '{print $$3}') --legacy --zksync

deploy-zk-sepolia:
	forge create src/FundMe.sol:FundMe --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account default --constructor-args 0xfEefF7c3fB57d18C5C6Cdd71e45D2D0b4F9377bF --legacy --zksync


# For deploying Interactions.s.sol:FundFundMe as well as for Interactions.s.sol:WithdrawFundMe we have to include a sender's address `--sender <ADDRESS>`
SENDER_ADDRESS := <sender's address>
 
fund:
	@forge script script/Interactions.s.sol:FundFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)

withdraw:
	@forge script script/Interactions.s.sol:WithdrawFundMe --sender $(SENDER_ADDRESS) $(NETWORK_ARGS)