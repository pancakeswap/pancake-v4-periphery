# Infinity periphery

## Running test

1. Install dependencies with `forge install`
2. Run test with `forge test --isolate`

See https://github.com/pancakeswap/infinity-core/pull/35 on why `--isolate` flag is used.

## Update dependencies

1. Run `forge update`

## Deployment

The scripts are located in `/script` folder, deployed contract address can be found in `script/config`

### Pre-req: before deployment, the follow env variable needs to be set
```
// set script config: /script/config/{SCRIPT_CONFIG}.json
export SCRIPT_CONFIG=ethereum-sepolia

// set rpc url
export RPC_URL=https://

// private key need to be prefixed with 0x
export PRIVATE_KEY=0x

// optional. Only set if you want to verify contract on explorer
export ETHERSCAN_API_KEY=xx
```

### Execute

Refer to the script source code for the specific commands: there are two commands—one for deployment and one for verification. A separate verification command is necessary because the contract is deployed through the create3Factory.

Example. within `script/02_DeployCLPositionManager.s.sol`
```
forge script script/02_DeployCLPositionManager.s.sol:DeployCLPositionManagerScript -vvv \
    --rpc-url $RPC_URL \
    --broadcast \
    --slow 

forge verify-contract <address> CLPositionManager --watch \
    --chain <chainId> --constructor-args $(cast abi-encode "constructor(address,address,address,uint256,address,address)" <vault> <clPoolManager> <permit2> <unsubscribeGasLimit> <clPositionDescriptor> <weth9>)
```
