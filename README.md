# Convertible Bonds

The Convertible Bond Box (CBB) is a enhancement to [ButtonBonds](https://github.com/buttonwood-protocol/tranche) that allows for a borrowers to deposit collateral and borrow stablecoins, while having the guaranteed option to repay before maturity in order to get the collateral back. This adds a few critical benefits as an add-on to the ButtonBonds being:

- Allows borrowers to buy back the SafeTranches that collateralized by the senior tranches. It is important to note that borrowers aren't guaranteed this opportunity with ButtonZero & UniSwap since lenders can purchase bonds and hold them indefinitely, eliminating liquidity.
- Gives lenders more confidence that a bond will be repaid via a penalty mechanism that is paid by borrowers if the stablecoins are not paid back by maturity.

Implementation also includes a Staging Box which is an enhanced refundable escrow box responsible for facilitating an Initial Bond Offering (IBO). A staging box is not required in order to issue a CBB, however can be very useful if the owner of the CBB is looking to primarily borrow OR lend. For example, if a DAO were to issue a CBB against their token with the intent of borrowing, the Staging Box would be useful for gauging market lending demand before committing to borrowing.

## Architecture
- [Slip.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/Slip.sol) : A regular ERC-20 whose minting and burning is only controlled by it's owner
  - [SlipFactory.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/SlipFactory.sol) : Proxy Factory which deploys an IOU slip token for any given collateral token
- [ConvertibleBondBox.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/ConvertibleBondBox.sol) : Core contract for convertibles, tied to a given ButtonBond
  - [CBBFactory.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/CBBFactory.sol) : Proxy Factory which deploys a CBB for a given ButtonBond
- [StagingBox.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/StagingBox.sol) : Core contract for holding IBO (initial bond offering) tied to a CBB
  - [StagingBoxFactory.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/StagingBoxFactory.sol) : Proxy Factory which deploys a CBB and then a Staging Box for a given ButtonBond
- [StagingLoanRouter.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/StagingLoanRouter.sol) : A router contract that allows users with raw non-rebasing tokens to directly participate in IBOs, and redeem across the elastic stack in atomic transactions
- [StagingBoxLens.sol](https://github.com/NimbleNavigatorsOrg/Forge-Lending-Box/blob/main/src/contracts/StagingBoxLens.sol) : A view function contract that provides maximums/expected amounts which is helpful for front-end design

![ConvertiblesArchitectureFlow](https://user-images.githubusercontent.com/92934445/178622965-cf9f8292-9579-4dc6-a238-bb0b236f350e.jpg)


## Documentation
See the link to our GitBooks and Technical Paper below

- [GitBooks](https://app.gitbook.com/s/Gik0CUdZJimrLH14a5vF/~/changes/nuk0LUx1x6lvYQyui4HH/the-elastic-finance-stack/what-are-buttontranches)
- Technical Paper

## Audits and Formal Verification

## Connect with the Community
You can join at the [Discord](https://discord.gg/DGWD2Sms) channel and follow us on [Twitter](https://twitter.com/nimblenavis).

## Setup

To install run:
```
git clone https://github.com/NimbleNavigatorsOrg/ButtonConvertibles-core.git

forge install
```

To run tests with [Foundry](https://github.com/foundry-rs/foundry) run:

```
forge update
```
and then:
```
forge test
```
