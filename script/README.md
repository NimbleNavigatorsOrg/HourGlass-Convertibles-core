# Using Scripts 

To get started with Scripts + Anvil, run Anvil: 
```
anvil
```
Then run the following to run the script on the Anvil local network. No need to change the private key, as it is from the Anvil account: 
```
forge script script/KovanAnvil.s.sol --fork-url http://127.0.0.1:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast
```

Next, get approval for tokens, by using Cast as follows, replacing $variables with the addresses console.log'd by the script where necessary: 
```
cast send $rawCollateralAddress "approve(address,uint256)" $stagingLoanRouterAddress $amount --rpc-url http://127.0.0.1:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 
```
Finally, complete a borrow as follows, again replacing the $variables: 
```
cast send $stagingLoanRouterAddress "simpleWrapTrancheBorrow(address,uint256,uint256)" $stagingBoxAddress $amount $amountMin --rpc-url http://127.0.0.1:8545  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 
```

To run the kovan batch deployer, run the following, replacing your private key: 
```
forge script script/KovanBatchDeployer.s.sol --rpc-url https://goerli.infura.io/v3/6b24bef7e22b42a18f7a9c46fab104b3 --private-key $private_key --broadcast --verify --etherscan-api-key 4DZZ49ARAJ8SXIC42GCWG3DF1WEEIJNQEI  -vvvv
```