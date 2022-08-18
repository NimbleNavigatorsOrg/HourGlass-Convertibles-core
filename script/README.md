# Using Scripts 

To get started with Scripts + Anvil, run Anvil: 
```
anvil
```
Then run the following to run the script on the Anvil local network. No need to change the private key, as it is from the Anvil account: 
```
forge script script/KovanAnvil.s.sol --fork-url $LOCAL_HOST_URL  --private-key $PRIVATE_KEY0  --broadcast
```

Next, get approval for tokens, by using Cast as follows, replacing $variables with the addresses console.log'd by the script where necessary: 
```
cast send $rawCollateralAddress "approve(address,uint256)" $stagingLoanRouterAddress $amount --rpc-url $LOCAL_HOST_URL  --private-key $PRIVATE_KEY0 
```
Finally, complete a borrow as follows, again replacing the $variables: 
```
cast send $stagingLoanRouterAddress "simpleWrapTrancheBorrow(address,uint256,uint256)" $stagingBoxAddress $amount $amountMin --rpc-url $LOCAL_HOST_URL  --private-key $PRIVATE_KEY0 
```

To run the Georli batch deployer, run the following, replacing your private key: 
```
forge script script/GoerliBatchDeployer.s.sol --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY_PERSONAL --broadcast --verify --etherscan-api-key 4DZZ49ARAJ8SXIC42GCWG3DF1WEEIJNQEI  -vvvv
```

To issue new CBBs, run the following: 

```
forge script script/GoerliCBBIssuer.s.sol --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY_PERSONAL --broadcast --verify --etherscan-api-key 4DZZ49ARAJ8SXIC42GCWG3DF1WEEIJNQEI  -vvvv
```

forge script script/GoerliBWSetup.s.sol --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY_PERSONAL

forge create --rpc-url $GOERLI_RPC_URL --private-key $PRIVATE_KEY_PERSONAL src/contracts/ConvertiblesDVLens.sol:ConvertiblesDVLens